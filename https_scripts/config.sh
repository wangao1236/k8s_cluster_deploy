#!/bin/bash

ETCD_SERVERS=$1
APISERVER=$2
BACKEND_APISERVER=$3
SSL_DIR=$4

export KUBE_APISERVER="http://$APISERVER:8080"
export KUBE_TLS_APISERVER="https://$APISERVER:8443"
export KUBE_BACKEND_TLS_APISERVER="https://$BACKEND_APISERVER:6443"

cat <<EOF >global
###
# kubernetes system config
#
# The following values are used to configure various aspects of all
# kubernetes services, including
#
#   kube-apiserver.service
#   kube-controller-manager.service
#   kube-scheduler.service
#   kubelet.service
#   kube-proxy.service
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=false"
 
# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=8"
 
# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=false"
 
# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=$KUBE_APISERVER"
EOF

cat <<EOF >controller-manager
###
# The following values are used to configure the kubernetes controller-manager
 
# defaults from config and apiserver should be adequate
 
# Add your own!
KUBE_CONTROLLER_MANAGER_ARGS="--log-file=/opt/kubernetes/log/controller-manager.log \\
--leader-elect=true \\
--bind-address=0.0.0.0 \\
--cluster-cidr=10.254.0.0/16 \\
--service-cluster-ip-range=10.254.0.0/16 \\
--controllers=*,bootstrapsigner,tokencleaner \\
--cluster-name=kubernetes \\
--tls-cert-file=/opt/kubernetes/ssl/admin.pem \\
--tls-private-key-file=/opt/kubernetes/ssl/admin-key.pem \\
--cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \\
--cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \\
--requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
--authentication-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
--authorization-kubeconfig=/opt/kubernetes/cfg/kube-controller-manager.kubeconfig \\
--root-ca-file=/opt/kubernetes/ssl/ca.pem \\
--service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \\
--secure-port=10257 \\
--experimental-cluster-signing-duration=87600h0m0s"
EOF

cat <<EOF >/opt/kubernetes/cfg/scheduler
###
# kubernetes scheduler config
 
# default config should be adequate
 
# Add your own!
KUBE_SCHEDULER_ARGS="--log-file=/opt/kubernetes/log/scheduler.log \\
--leader-elect=true \\
--tls-cert-file=/opt/kubernetes/ssl/admin.pem \\
--tls-private-key-file=/opt/kubernetes/ssl/admin-key.pem \\
--kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \\
--port=10251 \\
--secure-port=10259 \\
--bind-address=0.0.0.0 \\
--requestheader-client-ca-file=/opt/kubernetes/ssl/ca.pem \\
--authentication-kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \\
--authorization-kubeconfig=/opt/kubernetes/cfg/kube-scheduler.kubeconfig \\
--client-ca-file=/opt/kubernetes/ssl/ca.pem"
EOF

#----------------------

echo "===> generate test-user config"

# 创建 test-user config 

kubectl config set-cluster kubernetes \
  --certificate-authority=$SSL_DIR/ca.pem \
  --embed-certs=true \
  --server=${KUBE_TLS_APISERVER} \
  --kubeconfig=test-user.config

kubectl config set-credentials test-user \
  --client-certificate=$SSL_DIR/test-user.pem \
  --client-key=$SSL_DIR/test-user-key.pem \
  --embed-certs=true \
  --kubeconfig=test-user.config

kubectl config set-context test@kubernetes \
  --cluster=kubernetes \
  --user=test-user \
  --kubeconfig=test-user.config


kubectl config set-credentials admin \
  --client-certificate=$SSL_DIR/admin.pem \
  --client-key=$SSL_DIR/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=test-user.config

kubectl config set-context admin@kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=test-user.config

kubectl config use-context test@kubernetes --kubeconfig=test-user.config

#----------------------

echo "===> generate kubectl config"

# 创建 kubectl config 

kubectl config set-cluster kubernetes \
  --certificate-authority=$SSL_DIR/ca.pem \
  --embed-certs=true \
  --server=${KUBE_BACKEND_TLS_APISERVER} \
  --kubeconfig=config

kubectl config set-credentials test-user \
  --client-certificate=$SSL_DIR/test-user.pem \
  --client-key=$SSL_DIR/test-user-key.pem \
  --embed-certs=true \
  --kubeconfig=config

kubectl config set-context test@kubernetes \
  --cluster=kubernetes \
  --user=test-user \
  --kubeconfig=config


kubectl config set-credentials admin \
  --client-certificate=$SSL_DIR/admin.pem \
  --client-key=$SSL_DIR/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=config

kubectl config set-context admin@kubernetes \
  --cluster=kubernetes \
  --user=admin \
  --kubeconfig=config

kubectl config use-context admin@kubernetes --kubeconfig=config

#----------------------

echo "===> generate kube-controller-manager.kubeconfig"

# 创建 kube-controller-manager.kubeconfig

kubectl config set-cluster kubernetes \
  --certificate-authority=$SSL_DIR/ca.pem \
  --embed-certs=true \
  --server=${KUBE_TLS_APISERVER} \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials test-user \
  --client-certificate=$SSL_DIR/test-user.pem \
  --client-key=$SSL_DIR/test-user-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context system:kube-controller-manager@kubernetes \
  --cluster=kubernetes \
  --user=test-user \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context system:kube-controller-manager@kubernetes --kubeconfig=kube-controller-manager.kubeconfig

#----------------------

echo "===> generate kube-scheduler.kubeconfig"

# 创建 kube-scheduler.kubeconfig 

kubectl config set-cluster kubernetes \
  --certificate-authority=$SSL_DIR/ca.pem \
  --embed-certs=true \
  --server=${KUBE_TLS_APISERVER} \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials test-user \
  --client-certificate=$SSL_DIR/test-user.pem \
  --client-key=$SSL_DIR/test-user-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context system:kube-scheduler@kubernetes \
  --cluster=kubernetes \
  --user=test-user \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context system:kube-scheduler@kubernetes --kubeconfig=kube-scheduler.kubeconfig

#----------------------

echo "===> generate kubelet kubeconfig"

# 创建 kubelet kubeconfig 

# 设置集群参数
for instance in node1 node2 node3; do
kubectl config set-cluster kubernetes \
  --certificate-authority=$SSL_DIR/ca.pem \
  --embed-certs=true \
  --server=${KUBE_TLS_APISERVER} \
  --kubeconfig=${instance}.kubeconfig

# 设置客户端认证参数
kubectl config set-credentials system:node:${instance} \
    --client-certificate=$SSL_DIR/node/${instance}.pem \
    --client-key=$SSL_DIR/node/${instance}-key.pem \
    --kubeconfig=${instance}.kubeconfig

# 设置上下文参数
kubectl config set-context default \
  --cluster=kubernetes \
  --user=system:node:${instance} \
  --kubeconfig=${instance}.kubeconfig

# 设置默认上下文
kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

#----------------------

echo "===> generate kube-proxy.kubeconfig"

# 创建 kube-proxy.kubeconfig

kubectl config set-cluster kubernetes \
  --certificate-authority=$SSL_DIR/ca.pem \
  --embed-certs=true \
  --server=${KUBE_TLS_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials test-user \
  --client-certificate=$SSL_DIR/test-user.pem \
  --client-key=$SSL_DIR/test-user-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context system:kube-proxy@kubernetes \
  --cluster=kubernetes \
  --user=test-user \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context system:kube-proxy@kubernetes --kubeconfig=kube-proxy.kubeconfig

