#!/bin/bash

sudo mkdir -p /opt/kubernetes/{bin,cfg,log,ssl}
sudo rm -rf /opt/kubernetes/cfg/*
sudo rm -rf /opt/kubernetes/log/*
sudo rm -rf /opt/kubernetes/ssl/*
ssh root@master2 "mkdir -p /opt/kubernetes/{bin,cfg,log} && \
    rm -rf /opt/kubernetes/cfg/* && \
    rm -rf /opt/kubernetes/log/* && \
    rm -rf /opt/kubernetes/ssl/*"
ssh root@master3 "mkdir -p /opt/kubernetes/{bin,cfg,log} && \
    rm -rf /opt/kubernetes/cfg/* && \
    rm -rf /opt/kubernetes/log/* && \
    rm -rf /opt/kubernetes/ssl/*"

mkdir -p ../k8s-cert
sudo rm -rf ../k8s-cert/*
sudo rm -rf /opt/kubernetes/ssl/*
ssh root@master2 "rm -rf /opt/kubernetes/ssl/*"
ssh root@master3 "rm -rf /opt/kubernetes/ssl/*"
cp k8s-cert.sh ../k8s-cert
cd ../k8s-cert
./k8s-cert.sh
echo -e "\033[32m ======>>>>>>copy new cert \033[0m"
sudo cp -r ca* admin* test-user* master node /opt/kubernetes/ssl
sudo scp -r /opt/kubernetes/ssl root@master2:/opt/kubernetes/
sudo scp -r /opt/kubernetes/ssl root@master3:/opt/kubernetes/
cd ../https_scripts

mkdir -p ../config
sudo rm -rf ../config/*
sudo rm -rf /opt/kubernetes/cfg/*
ssh root@master2 "rm -rf /opt/kubernetes/cfg/*"
ssh root@master3 "rm -rf /opt/kubernetes/cfg/*"
cp config.sh ../config
cd ../config
sudo ./config.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 192.168.1.66 192.168.1.67 /opt/kubernetes/ssl
echo -e "\033[32m ======>>>>>>copy new config \033[0m"
sudo cp * /opt/kubernetes/cfg
sudo chown ao:ao config
sudo chown ao:ao test-user.config
cp config ~/.kube/
cp test-user.config ~/.kube/
sudo scp /opt/kubernetes/cfg/* root@master2:/opt/kubernetes/cfg/
scp config ao@master2:/home/ao/.kube/
sudo scp /opt/kubernetes/cfg/* root@master3:/opt/kubernetes/cfg/
scp config ao@master3:/home/ao/.kube/
cd ../https_scripts

echo -e "\033[32m ======>>>>>>restart nginx \033[0m"
ssh root@lb2 "systemctl stop nginx.service && \
    systemctl disable nginx.service && \
    rm /var/log/nginx/*"
sudo scp -r /opt/kubernetes/ssl/* root@lb2:/etc/nginx/ssl/
ssh root@lb2 "cd /etc/nginx/ssl && \
    cat admin.pem > test.pem && \
    cat admin-key.pem > test-key.pem && \
    systemctl stop haproxy.service && \
    systemctl daemon-reload && \
    systemctl restart nginx.service && \
    systemctl status nginx.service"

echo -e "\033[32m ======>>>>>>restart etcd \033[0m"
sudo systemctl stop etcd.service
ssh root@master2 "systemctl stop etcd.service"
ssh root@master3 "systemctl stop etcd.service"
sleep 5s
sudo rm -rf /var/lib/etcd/default.etcd/member
ssh root@master2 "rm -rf /var/lib/etcd/default.etcd/member"
ssh root@master3 "rm -rf /var/lib/etcd/default.etcd/member"
sleep 5s
sudo systemctl daemon-reload
sudo systemctl restart etcd.service
ssh root@master2 "systemctl daemon-reload && \
    systemctl restart etcd.service && \
    systemctl status etcd.service"
ssh root@master3 "systemctl daemon-reload && \
    systemctl restart etcd.service && \
    systemctl status etcd.service"
sudo etcdctl --ca-file=/opt/etcd/ssl/ca.pem --cert-file=/opt/etcd/ssl/server.pem --key-file=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.1.67:2379,https://192.168.1.68,https://192.168.1.69" cluster-health
sudo etcdctl --ca-file=/opt/etcd/ssl/ca.pem --cert-file=/opt/etcd/ssl/server.pem --key-file=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.1.67:2379,https://192.168.1.68,https://192.168.1.69" rmdir /coreos.com/network
sudo etcdctl --ca-file=/opt/etcd/ssl/ca.pem --cert-file=/opt/etcd/ssl/server.pem --key-file=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.1.67:2379,https://192.168.1.68,https://192.168.1.69" set /coreos.com/network/config '{ "Network": "172.17.0.0/16", "Backend": {"Type": "vxlan"}}'
echo -e "\033[32m ======>>>>>>restart flannel && docker \033[0m"
sudo ./flannel.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379
scp flannel.sh ao@master2:/home/ao/Coding/k8s/https_scripts
scp flannel.sh ao@master3:/home/ao/Coding/k8s/https_scripts
sudo systemctl daemon-reload 
sudo systemctl restart docker
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./flannel.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 && \
    systemctl daemon-reload && \
    systemctl restart docker && \
    systemctl status docker"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./flannel.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 && \
    systemctl daemon-reload && \
    systemctl restart docker && \
    systemctl status docker"

echo -e "\033[32m ======>>>>>>restart kube-apiserver \033[0m"
sudo systemctl stop kube-apiserver
ssh root@master2 systemctl stop kube-apiserver 
ssh root@master3 systemctl stop kube-apiserver
sudo ./apiserver.sh 192.168.1.67 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379
scp apiserver.sh ao@master2:/home/ao/Coding/k8s/https_scripts && scp apiserver.sh ao@master3:/home/ao/Coding/k8s/https_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./apiserver.sh 192.168.1.68 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./apiserver.sh 192.168.1.69 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379"

echo -e "\033[32m ======>>>>>>restart kube-controller-manager \033[0m"
sudo systemctl stop kube-controller-manager
ssh root@master2 systemctl stop kube-controller-manager
ssh root@master3 systemctl stop kube-controller-manager
sudo ./controller-manager.sh
scp controller-manager.sh ao@master2:/home/ao/Coding/k8s/https_scripts && scp controller-manager.sh ao@master3:/home/ao/Coding/k8s/https_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./controller-manager.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./controller-manager.sh"

echo -e "\033[32m ======>>>>>>restart kube-scheduler \033[0m"
sudo systemctl stop kube-scheduler
ssh root@master2 systemctl stop kube-scheduler
ssh root@master3 systemctl stop kube-scheduler
sudo ./scheduler.sh
scp scheduler.sh ao@master2:/home/ao/Coding/k8s/https_scripts && scp scheduler.sh ao@master3:/home/ao/Coding/k8s/https_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./scheduler.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./scheduler.sh"

echo -e "\033[32m ======>>>>>>restart kubelet \033[0m"
sudo systemctl stop kubelet
ssh root@master2 systemctl stop kubelet
ssh root@master3 systemctl stop kubelet
sudo ./kubelet.sh 192.168.1.67 node1
scp kubelet.sh ao@master2:/home/ao/Coding/k8s/https_scripts && scp kubelet.sh ao@master3:/home/ao/Coding/k8s/https_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./kubelet.sh 192.168.1.68 node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./kubelet.sh 192.168.1.69 node3"

echo -e "\033[32m ======>>>>>>restart proxy \033[0m"
sudo systemctl stop kube-proxy
ssh root@master2 systemctl stop kube-proxy
ssh root@master3 systemctl stop kube-proxy
sudo ./proxy.sh node1
scp proxy.sh ao@master2:/home/ao/Coding/k8s/https_scripts && scp proxy.sh ao@master3:/home/ao/Coding/k8s/https_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./proxy.sh node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/https_scripts && \
    ./proxy.sh node3"

kubectl delete -f ../yamls/jobs-tester.yaml
kubectl delete clusterrolebinding jobs-test
kubectl delete clusterrolebinding test-cluster-admin-binding
kubectl apply -f ../yamls/jobs-tester.yaml
kubectl create clusterrolebinding jobs-test --clusterrole=jobs-tester --user=test-user
kubectl create clusterrolebinding test-cluster-admin-binding --clusterrole=cluster-admin --user=test-user

echo "1st"
sleep 10s
kubectl label node node1 node2 node3 node-role.kubernetes.io/master=true
echo "2nd"
kubectl get nodes --all-namespaces
kubectl taint nodes --all node-role.kubernetes.io/master=true:NoSchedule
kubectl taint nodes --all node-role.kubernetes.io/master-
sleep 10s
echo "3rd"
kubectl get nodes --all-namespaces
kubectl delete -f ../yamls/nginx-deployment.yaml
sleep 5s
kubectl apply -f ../yamls/nginx-deployment.yaml
kubectl get pods --all-namespaces
