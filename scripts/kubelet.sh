#!/bin/bash

NODE_ADDRESS=$1
NODE_NAME=$2
DNS_SERVER_IP=${3:-"10.254.0.2"}

systemctl stop kubelet
systemctl disable kubelet

cat <<EOF >/opt/kubernetes/cfg/kubelet

KUBELET_OPTS="--logtostderr=false \\
--v=4 \\
--log-file=/opt/kubernetes/log/node.log \\
--config=/opt/kubernetes/cfg/kubelet.config \\
--node-ip=${NODE_ADDRESS} \\
--bootstrap-kubeconfig=/opt/kubernetes/cfg/bootstrap.kubeconfig \\
--cert-dir=/opt/kubernetes/ssl/node \\
--hostname-override=${NODE_NAME} \\
--node-labels=node.kubernetes.io/k8s-master=true \\
--kubeconfig=/opt/kubernetes/cfg/kubelet.kubeconfig \\
--pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google-containers/pause-amd64:3.0"

EOF

#--cni-bin-dir=/opt/cni/bin \\
#--cni-conf-dir=/opt/cni/net.d \\
#--network-plugin=cni \\


cat <<EOF >/opt/kubernetes/cfg/kubelet.config

kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: ${NODE_ADDRESS}
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS:
- ${DNS_SERVER_IP}
clusterDomain: cluster.local.
failSwapOn: false
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/opt/kubernetes/ssl/ca.pem"
authorization:
  mode: Webhook

EOF

cat <<EOF >/usr/lib/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
After=docker.service
Requires=docker.service

[Service]
EnvironmentFile=/opt/kubernetes/cfg/kubelet
ExecStart=/opt/kubernetes/bin/kubelet \$KUBELET_OPTS
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kubelet
systemctl restart kubelet
