#!/bin/bash

NODE_NAME=$1

systemctl stop kube-proxy
systemctl disable kube-proxy

cat <<EOF >/opt/kubernetes/cfg/proxy
KUBE_PROXY_ARGS="--log-file=/opt/kubernetes/log/proxy.log \\
--bind-address=0.0.0.0 \\
--config=/opt/kubernetes/cfg/kube-proxy.config \\
--cleanup-ipvs=true \\
--proxy-mode=ipvs"
EOF

cat <<EOF >/opt/kubernetes/cfg/kube-proxy.config

kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 0.0.0.0
hostnameOverride: ${NODE_NAME}
clusterCIDR: "10.254.0.0/16"
ipvs:
  minSyncPeriod: 5s
  scheduler: "wrr"
  syncPeriod: 5s
clientConnection:
  kubeconfig: "/opt/kubernetes/cfg/kube-proxy.kubeconfig"

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
\$KUBE_PROXY_ARGS

Restart=on-failure
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-proxy
systemctl restart kube-proxy
