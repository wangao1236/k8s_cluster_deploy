#!/bin/bash

sudo mkdir -p /opt/kubernetes/{bin,cfg,log}
sudo rm -rf /opt/kubernetes/cfg/*
sudo rm -rf /opt/kubernetes/log/*
ssh root@master2 "mkdir -p /opt/kubernetes/{bin,cfg,log} && \
    rm -rf /opt/kubernetes/cfg/* && \
    rm -rf /opt/kubernetes/log/*"
ssh root@master3 "mkdir -p /opt/kubernetes/{bin,cfg,log} && \
    rm -rf /opt/kubernetes/cfg/* && \
    rm -rf /opt/kubernetes/log/*"

mkdir -p ../config
sudo rm -rf ../config/*
sudo rm /opt/kubernetes/cfg/*
ssh root@master2 "rm -rf /opt/kubernetes/cfg/*"
ssh root@master3 "rm -rf /opt/kubernetes/cfg/*"
cp config.sh ../config
cd ../config
sudo ./config.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 192.168.1.66
sudo cp * /opt/kubernetes/cfg
sudo chown ao:ao config
cp config ~/.kube/
sudo scp /opt/kubernetes/cfg/* root@master2:/opt/kubernetes/cfg/
scp config ao@master2:/home/ao/.kube/
sudo scp /opt/kubernetes/cfg/* root@master3:/opt/kubernetes/cfg/
scp config ao@master3:/home/ao/.kube/
cd ../http_scripts

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
sudo ./apiserver.sh 192.168.1.67 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379
scp apiserver.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp apiserver.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./apiserver.sh 192.168.1.68 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./apiserver.sh 192.168.1.69 https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379"

echo -e "\033[32m ======>>>>>>restart kube-controller-manager \033[0m"
sudo ./controller-manager.sh
scp controller-manager.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp controller-manager.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./controller-manager.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./controller-manager.sh"

echo -e "\033[32m ======>>>>>>restart kube-scheduler \033[0m"
sudo ./scheduler.sh
scp scheduler.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp scheduler.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./scheduler.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./scheduler.sh"

echo -e "\033[32m ======>>>>>>restart kubelet \033[0m"
sudo ./kubelet.sh 192.168.1.67 node1
scp kubelet.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp kubelet.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./kubelet.sh 192.168.1.68 node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./kubelet.sh 192.168.1.69 node3"

echo -e "\033[32m ======>>>>>>restart proxy \033[0m"
sudo ./proxy.sh node1
scp proxy.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp proxy.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./proxy.sh node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./proxy.sh node3"

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
kubectl apply -f ../yamls//nginx-deployment.yaml
kubectl get pods --all-namespaces
