#!/bin/bash


MASTER_ADDRESS=$1
ETCD_SERVERS=$2

systemctl stop kube-apiserver
systemctl disable kube-apiserver

cat <<EOF >/opt/kubernetes/cfg/apiserver

KUBE_API_ADDRESS="--insecure-bind-address=${MASTER_ADDRESS}"

KUBE_API_PORT="--port=8080"

KUBELET_PORT="--kubelet-port=10250"

KUBE_ETCD_SERVERS="--etcd-servers=${ETCD_SERVERS}"
KUBE_ETCD_CAFILE="--etcd-cafile=/opt/etcd/ssl/ca.pem"
KUBE_ETCD_CERTFILE="--etcd-certfile=/opt/etcd/ssl/server.pem"
KUBE_ETCD_KEYFILE="--etcd-keyfile=/opt/etcd/ssl/server-key.pem"

KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"

KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota"

# Add your own!
KUBE_API_ARGS="--log-file=/opt/kubernetes/log/apiserver.log \\
--advertise-address=${MASTER_ADDRESS}"
EOF

cat <<EOF >/usr/lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service
 
[Service]
EnvironmentFile=-/opt/kubernetes/cfg/global
EnvironmentFile=-/opt/kubernetes/cfg/apiserver
ExecStart=/opt/kubernetes/bin/kube-apiserver \\
\$KUBE_LOGTOSTDERR \\
\$KUBE_LOG_LEVEL \\
\$KUBE_ETCD_SERVERS \\
\$KUBE_ETCD_CAFILE \\
\$KUBE_ETCD_CERTFILE \\
\$KUBE_ETCD_KEYFILE \\
\$KUBE_API_ADDRESS \\
\$KUBE_API_PORT \\
\$KUBELET_PORT \\
\$KUBE_ALLOW_PRIV \\
\$KUBE_SERVICE_ADDRESSES \\
\$KUBE_ADMISSION_CONTROL \\
\$KUBE_API_ARGS

Restart=on-failure
Type=notify
LimitNOFILE=65536
 
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-apiserver
systemctl restart kube-apiserver
