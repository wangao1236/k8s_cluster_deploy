#!/bin/bash

#------------- update cert && kubeconfig
echo -e "\033[32m ======>>>>>>delete old cert && kubeconfig \033[0m"
rm -rf ../k8s-cert/*
rm -rf ../kubeconfig/*
sudo rm -rf /opt/kubernetes/ssl/*
ssh root@master2 rm -rf /opt/kubernetes/ssl/*
ssh root@master3 rm -rf /opt/kubernetes/ssl/*
echo -e "\033[32m ======>>>>>>generate new cert \033[0m"
cp k8s-cert.sh ../k8s-cert
cd ../k8s-cert
./k8s-cert.sh
echo -e "\033[32m ======>>>>>>copy new cert \033[0m"
sudo cp -r ca* admin* master node /opt/kubernetes/ssl
sudo scp -r /opt/kubernetes/ssl root@master2:/opt/kubernetes/
sudo scp -r /opt/kubernetes/ssl root@master3:/opt/kubernetes/
echo -e "\033[32m ======>>>>>>generate new kubeconfig \033[0m"
cd ../scripts
sudo rm -rf /opt/kubernetes/cfg/*
ssh root@master2 rm -rf /opt/kubernetes/cfg/*
ssh root@master3 rm -rf /opt/kubernetes/cfg/*
cp kubeconfig.sh ../kubeconfig
cd ../kubeconfig
sudo ./kubeconfig.sh 192.168.1.65 /opt/kubernetes/ssl
echo -e "\033[32m ======>>>>>>copy new kubeconfig \033[0m"
sudo cp * /opt/kubernetes/cfg
sudo scp -r /opt/kubernetes/cfg root@master2:/opt/kubernetes/
sudo scp -r /opt/kubernetes/cfg root@master3:/opt/kubernetes/
sudo chown ao:ao config
cp config /home/ao/.kube/
scp config ao@master2:/home/ao/.kube/
scp config ao@master3:/home/ao/.kube/
cd ../scripts
#------------- restart components
echo -e "\033[32m ======>>>>>>restart etcd \033[0m"
sudo rm -rf /var/lib/etcd/default.etcd/member
ssh root@master2 "rm -rf /var/lib/etcd/default.etcd/member"
ssh root@master3 "rm -rf /var/lib/etcd/default.etcd/member"
sleep 10s
sudo systemctl daemon-reload
sudo systemctl restart etcd.service
ssh root@master2 "systemctl daemon-reload && \
    systemctl restart etcd.service && \
    systemctl status etcd.service"
ssh root@master3 "systemctl daemon-reload && \
    systemctl restart etcd.service && \
    systemctl status etcd.service"
sudo etcdctl --ca-file=/opt/etcd/ssl/ca.pem --cert-file=/opt/etcd/ssl/server.pem --key-file=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.1.67:2379,https://192.168.1.68,https://192.168.1.69" cluster-health
sudo etcdctl --ca-file=/opt/etcd/ssl/ca.pem --cert-file=/opt/etcd/ssl/server.pem --key-file=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.1.67:2379,https://192.168.1.68,https://192.168.1.69" set /coreos.com/network/config '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
echo -e "\033[32m ======>>>>>>restart flannel && docker \033[0m"
sudo ./flannel.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 
scp flannel.sh ao@master2:/home/ao/Coding/k8s/scripts && scp flannel.sh ao@master3:/home/ao/Coding/k8s/scripts
sudo systemctl daemon-reload 
sudo systemctl restart docker
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./flannel.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 && \
    systemctl daemon-reload && \
    systemctl restart docker && \
    systemctl status docker"

ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./flannel.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 && \
    systemctl daemon-reload && \
    systemctl restart docker && \
    systemctl status docker"

echo -e "\033[32m ======>>>>>>restart kube-apiserver \033[0m"
sudo systemctl stop kube-apiserver
ssh root@master2 systemctl stop kube-apiserver 
ssh root@master3 systemctl stop kube-apiserver
sudo ./apiserver.sh 192.168.1.67 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379
scp apiserver.sh ao@master2:/home/ao/Coding/k8s/scripts && scp apiserver.sh ao@master3:/home/ao/Coding/k8s/scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./apiserver.sh 192.168.1.68 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./apiserver.sh 192.168.1.69 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379"

echo -e "\033[32m ======>>>>>>restart kube-controller-manager \033[0m"
sudo systemctl stop kube-controller-manager
ssh root@master2 systemctl stop kube-controller-manager
ssh root@master3 systemctl stop kube-controller-manager
sudo ./controller-manager.sh
scp controller-manager.sh ao@master2:/home/ao/Coding/k8s/scripts && scp controller-manager.sh ao@master3:/home/ao/Coding/k8s/scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./controller-manager.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./controller-manager.sh"

echo -e "\033[32m ======>>>>>>restart kube-scheduler \033[0m"
sudo systemctl stop kube-scheduler
ssh root@master2 systemctl stop kube-scheduler
ssh root@master3 systemctl stop kube-scheduler
sudo ./scheduler.sh
scp scheduler.sh ao@master2:/home/ao/Coding/k8s/scripts && scp scheduler.sh ao@master3:/home/ao/Coding/k8s/scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./scheduler.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./scheduler.sh"

echo -e "\033[32m ======>>>>>>check cluster info \033[0m"
kubectl cluster-info

echo -e "\033[32m ======>>>>>>delete cluster info \033[0m"
kubectl delete clusterrolebinding kubelet-bootstrap
kubectl delete clusterrolebinding kube-apiserver:kubelet-apis
kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap
kubectl delete node --all
kubectl delete csr --all

echo -e "\033[32m ======>>>>>>restart kubelet \033[0m"
sudo systemctl stop kubelet
ssh root@master2 systemctl stop kubelet
ssh root@master3 systemctl stop kubelet
sudo ./kubelet.sh 192.168.1.67 node1
scp kubelet.sh ao@master2:/home/ao/Coding/k8s/scripts && scp kubelet.sh ao@master3:/home/ao/Coding/k8s/scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./kubelet.sh 192.168.1.68 node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./kubelet.sh 192.168.1.69 node3"

sleep 3s

echo -e "\033[32m ======>>>>>>add nodes \033[0m"
kubectl get csr

sleep 3s

cmd_approve="kubectl certificate approve"
cmd_csrs=$(kubectl get csr | grep -E -o 'node-csr-.{43}')
echo $cmd_csrs
csr_array=(${cmd_csrs//,/ })
for var in ${csr_array[@]}
do
    echo $var
    cmd_approve="$cmd_approve $var"
done
eval $cmd_approve

kubectl get csr

echo -e "\033[32m ======>>>>>>check nodes \033[0m"
sleep 10s
echo "1st"
kubectl get nodes
kubectl label node node1 node2 node3 node-role.kubernetes.io/master=true
echo "2nd"
kubectl get nodes
kubectl taint nodes --all node-role.kubernetes.io/master=true:NoSchedule
kubectl taint nodes --all node-role.kubernetes.io/master-
sleep 10s
echo "3rd"
kubectl get nodes

echo -e "\033[32m ======>>>>>>restart kube-proxy \033[0m"
sudo systemctl stop kube-proxy
ssh root@master2 systemctl stop kube-proxy
ssh root@master3 systemctl stop kube-proxy
sudo ./proxy.sh node1
scp proxy.sh ao@master2:/home/ao/Coding/k8s/scripts && scp proxy.sh ao@master3:/home/ao/Coding/k8s/scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./proxy.sh node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/scripts && \
    ./proxy.sh node3"

cd ../yamls
./rebuild-pod.sh
cd ../scripts
sleep 10s
echo "4th"
kubectl get nodes
sleep 10s
kubectl get pods
