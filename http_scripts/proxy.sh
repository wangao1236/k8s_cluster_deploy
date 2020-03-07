#!/bin/bash

NODE_NAME=$1

systemctl stop kube-proxy
systemctl disable kube-proxy

cat <<EOF >/opt/kubernetes/cfg/proxy
KUBE_PROXY_OPTS="--bind-address=0.0.0.0 \\
--hostname-override=${NODE_NAME} \\
--cleanup-ipvs=true \\
--cluster-cidr=10.254.0.0/16 \\
--proxy-mode=ipvs \\
--ipvs-min-sync-period=5s \\
--ipvs-sync-period=5s \\
--ipvs-scheduler=wrr \\
--masquerade-all=true"
EOF

cat <<EOF >/usr/lib/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
 
[Service]
EnvironmentFile=-/opt/kubernetes/cfg/global
EnvironmentFile=-/opt/kubernetes/cfg/proxy
ExecStart=/opt/kubernetes//bin/kube-proxy \\
\$KUBE_LOGTOSTDERR \\
\$KUBE_LOG_LEVEL \\
\$KUBE_MASTER \\
\$KUBE_PROXY_ARGS

Restart=on-failure
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-proxy
systemctl restart kube-proxy
