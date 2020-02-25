#!/bin/bash

systemctl stop kube-scheduler
systemctl disable kube-scheduler

cat <<EOF >/opt/kubernetes/cfg/kube-scheduler

KUBE_SCHEDULER_OPTS="--logtostderr=true \\
--v=4 \\
--bind-address=0.0.0.0 \\
--port=10251 \\
--secure-port=10259 \\
--kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \\
--requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--authentication-kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \\
--authorization-kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \\
--client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--tls-cert-file=/opt/kubernetes/ssl/master/kube-scheduler.pem \\
--tls-private-key-file=/opt/kubernetes/ssl/master/kube-scheduler-key.pem \\
--leader-elect=true"

EOF

cat <<EOF >/usr/lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/kube-scheduler
ExecStart=/opt/kubernetes/bin/kube-scheduler \$KUBE_SCHEDULER_OPTS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kube-scheduler
systemctl restart kube-scheduler
