#!/bin/bash

systemctl stop kube-controller-manager.service 
systemctl disable kube-controller-manager.service

cat <<EOF >/opt/kubernetes/cfg/kube-controller-manager

KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=false \\
--v=8 \\
--log-file=/opt/kubernetes/log/controller-manager.log \\
--bind-address=0.0.0.0 \\
--cluster-name=kubernetes \\
--kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
--requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--authentication-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
--authorization-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
--leader-elect=true \\
--service-cluster-ip-range=10.254.0.0/16 \\
--controllers=*,bootstrapsigner,tokencleaner \\
--tls-cert-file=/opt/kubernetes/ssl/admin.pem \\
--tls-private-key-file=/opt/kubernetes/ssl/admin-key.pem \\
--cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \\
--cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem  \\
--root-ca-file=/opt/kubernetes/ssl/ca.pem \\
--service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \\
--secure-port=10257 \\
--experimental-cluster-signing-duration=87600h0m0s"

EOF

#--use-service-account-credentials=true \\
#--allocate-node-cidrs=true \\
#--cluster-cidr=172.17.0.0/16 \\

cat <<EOF >/usr/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-controller-manager
ExecStart=/opt/kubernetes/bin/kube-controller-manager \$KUBE_CONTROLLER_MANAGER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-controller-manager
systemctl restart kube-controller-manager
