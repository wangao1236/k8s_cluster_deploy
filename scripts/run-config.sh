#!/bin/bash

UPDATE=0
NGINX=0
TEST=0

while [[ $# -ge 1 ]]; do
    case $1 in
        -u|--update )
            UPDATE=$2
            shift 2
            ;;
        -n|--nginx )
            NGINX=$2
            shift 2
            ;;
        -t|--test )
            TEST=$2
            shift 2
            ;;
    esac
done

echo "UPDATE=$UPDATE; NGINX=$NGINX; TEST=$TEST"

#------------- update cert && kubeconfig
function update_cert_kubeconfig() {
    echo -e "\033[32m ======>>>>>>delete old cert && kubeconfig \033[0m"
    rm -rf ../k8s-cert/*
    rm -rf ../kubeconfig/*
    rm -rf ../audit/*
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
    ssh root@master2 rm -rf /opt/kubernetes/cfg/*
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
    cd ../audit
cat > audit-policy.yaml <<EOF
# Log all requests at the Metadata level.
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
EOF
    echo -e "\033[32m ======>>>>>>copy new audit-policy \033[0m"
    sudo cp audit-policy.yaml /opt/kubernetes/cfg
    sudo scp /opt/kubernetes/cfg/audit-policy.yaml root@master2:/opt/kubernetes/cfg
    sudo scp /opt/kubernetes/cfg/audit-policy.yaml root@master3:/opt/kubernetes/cfg
    cd ../scripts
}

if [ $UPDATE -eq 1 ]; then
    update_cert_kubeconfig
fi

#------------- clear logs
echo -e "\033[32m ======>>>>>>clear logs \033[0m"
sudo rm /opt/kubernetes/log/*
ssh root@master2 "rm /opt/kubernetes/log/*"
ssh root@master3 "rm /opt/kubernetes/log/*"

#------------- restart components
echo -e "\033[32m ======>>>>>>restart haproxy \033[0m"
if [ $UPDATE -eq 1 ]; then
    ssh root@lb1 "systemctl stop nginx.service && \
        systemctl start haproxy.service"
fi

if [ $TEST -eq 1 ]; then
    ssh root@lb1 "systemctl stop nginx.service && \
        systemctl disable nginx.service && \
        rm /var/log/nginx/*"
    sudo scp -r /opt/kubernetes/ssl/* root@lb1:/etc/nginx/ssl/
    ssh root@lb1 "cd /etc/nginx/ssl && \
        cat admin.pem > test.pem && \
        cat admin-key.pem > test-key.pem && \
        systemctl stop haproxy.service && \
        systemctl enable nginx.service && \
        systemctl daemon-reload && \
        systemctl restart nginx.service && \
        systemctl status nginx.service"
fi

echo -e "\033[32m ======>>>>>>restart etcd \033[0m"
sudo systemctl stop etcd.service
ssh root@master2 "systemctl stop etcd.service"
ssh root@master3 "systemctl stop etcd.service"
sleep 10s
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
kubectl delete clusterrolebinding kube-apiserver
kubectl delete clusterrolebinding kube-controller-manager
kubectl create clusterrolebinding kube-apiserver --clusterrole=system:kubelet-api-admin --user=admin
kubectl create clusterrolebinding kube-controller-manager --clusterrole=system:kube-controller-manager --user=admin
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --group=system:nodes
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
echo ">>>>>>>>>>>>>>>>>>>1"
ssh root@lb1 "cd /etc/nginx/ssl && \
    rm -rf *"
echo ">>>>>>>>>>>>>>>>>>>2"
sudo scp -r /opt/kubernetes/ssl/* root@lb1:/etc/nginx/ssl/
echo ">>>>>>>>>>>>>>>>>>>3"
ssh root@lb1 "ls -l /etc/nginx/ssl/"
echo ">>>>>>>>>>>>>>>>>>>4"
echo "1st"
cmd_check_node=$(kubectl get nodes | grep -E -o 'not found')
not_found_array=(${cmd_check_node//,/ })
while [ ${#not_found_array[@]} -gt 0 ]
do
    echo -e "\033[31m !!!!!!!! Waiting for node to be ready \033[0m"
    sleep 3s
    cmd_check_node=$(kubectl get nodes | grep -E -o 'not found')
    not_found_array=(${cmd_check_node//,/ })
done

sleep 10s

if [ $NGINX -eq 1 ]; then
    #while [ ! -f "/opt/kubernetes/ssl/node/kubelet-client-current.pem" ]; do
    #    sleep 3s
    #    echo -e "\033[31m Waiting for file named '/opt/kubernetes/ssl/node/kubelet-client-current.pem' to be made \033[0m"
    #done
    echo -e "\033[32m ======>>>>>>restart nginx \033[0m"
    ssh root@lb1 "cd /etc/nginx/ssl && \
        rm -rf *"
    sudo scp -r /opt/kubernetes/ssl/* root@lb1:/etc/nginx/ssl/
    ssh root@lb1 "ls -l /etc/nginx/ssl/"
    ssh root@lb1 "cd /etc/nginx/ssl && \
        cat admin.pem > test.pem && \
        cat admin-key.pem > test-key.pem && \
        systemctl stop haproxy.service && \
        systemctl daemon-reload && \
        systemctl restart nginx.service && \
        systemctl status nginx.service"
#    ssh root@lb1 "cd /etc/nginx/ssl && \
#        cat admin.pem > test.pem && \
#        cat node/kubelet-client-current.pem |head -n 17 | tail -n +1 >> test.pem >> test.pem && \
#        cat admin-key.pem > test-key.pem && \
#        cat node/kubelet-client-current.pem |head -n 22 | tail -n +18 >> test-key.pem && \
#        systemctl stop haproxy.service && \
#        systemctl daemon-reload && \
#        systemctl restart nginx.service && \
#        systemctl status nginx.service"
fi

echo -e "\033[32m ======>>>>>>add nodes \033[0m"
kubectl get csr
sleep 10s
kubectl get node
sleep 10s
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
kubectl get nodes --all-namespaces
sleep 10s
kubectl get pods --all-namespaces
