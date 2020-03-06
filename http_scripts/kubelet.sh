#!/bin/bash

NODE_ADDRESS=$1
NODE_NAME=$2
DNS_SERVER_IP=${3:-"10.254.0.2"}

systemctl stop kubelet
systemctl disable kubelet

cat <<EOF >/usr/lib/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service
 
[Service]
EnvironmentFile=-/opt/kubernetes/cfg/config
EnvironmentFile=-/opt/kubernetes/cfg/kubelet
ExecStart=/opt/kubernetes/bin/kubelet \
            $KUBE_LOGTOSTDERR \
            $KUBE_LOG_LEVEL \
            $KUBELET_API_SERVER \
            $KUBELET_ADDRESS \
            $KUBELET_PORT \
            $KUBELET_HOSTNAME \
            $KUBE_ALLOW_PRIV \
            $KUBELET_ARGS \
            --address=$NODE_ADDRESS \
            --hostname-override=$NODE_NAME

Restart=on-failure
KillMode=process
 
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet
