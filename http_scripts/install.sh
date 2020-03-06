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
rm ../config/*
ssh root@master2 "rm /opt/kubernetes/cfg/*"
ssh root@master3 "rm /opt/kubernetes/cfg/*"
cp config.sh ../config
cd ../config
./config.sh https://192.168.1.67:2379,https://192.168.1.68:2379,https://192.168.1.69:2379 192.168.1.66
sudo cp * /opt/kubernetes/cfg
sudo scp /opt/kubernetes/cfg/* root@master2:/opt/kubernetes/cfg/
sudo scp /opt/kubernetes/cfg/* root@master3:/opt/kubernetes/cfg/
cd ../http_script

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

./apiserver.sh
scp apiserver.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp apiserver.sh ao@master3:/home/ao/Coding/http_k8s/scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./apiserver.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./apiserver.sh"

./controller.sh
scp controller-manager.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp controller-manager.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./controller-manager.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./controller-manager.sh"

./scheduler.sh
scp scheduler.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp scheduler.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./scheduler.sh"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./scheduler.sh"

./kubelet.sh 192.168.1.67 node1
scp kubelet.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp kubelet.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./kubelet.sh 192.168.1.68 node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./kubelet.sh 192.168.1.69 node3"

./proxy.sh node1
scp proxy.sh ao@master2:/home/ao/Coding/k8s/http_scripts && scp proxy.sh ao@master3:/home/ao/Coding/k8s/http_scripts
ssh root@master2 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./proxy.sh node2"
ssh root@master3 "hostname && \
    cd /home/ao/Coding/k8s/http_scripts && \
    ./proxy.sh node3"
