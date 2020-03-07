#!/bin/bash

ETCD_SERVERS=$1
APISERVER=$2

export KUBE_APISERVER="http://$APISERVER:8080"

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
KUBE_MASTER="--master=http://$APISERVER:8080"
EOF

cat <<EOF >controller-manager
###
# The following values are used to configure the kubernetes controller-manager
 
# defaults from config and apiserver should be adequate
 
# Add your own!
KUBE_CONTROLLER_MANAGER_ARGS="--log-file=/opt/kubernetes/log/controller-manager.log \\
--leader-elect=true \\
--service-cluster-ip-range=10.254.0.0/16 \\
--controllers=*,bootstrapsigner,tokencleaner \\
--cluster-name=kubernetes"
EOF

cat <<EOF >/opt/kubernetes/cfg/scheduler
###
# kubernetes scheduler config
 
# default config should be adequate
 
# Add your own!
KUBE_SCHEDULER_ARGS="--log-file=/opt/kubernetes/log/scheduler.log"
EOF

kubectl config set-cluster kubernetes \
  --server=${KUBE_APISERVER} \
  --embed-certs=false \
  --kubeconfig=config

kubectl config set-context default \
  --cluster=kubernetes \
  --user="" \
  --kubeconfig=config

kubectl config use-context default --kubeconfig=config

kubectl config set-cluster kubernetes \
  --embed-certs=false \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kubelet.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user="" \
  --kubeconfig=kubelet.kubeconfig

# 设置默认上下文
kubectl config use-context default --kubeconfig=kubelet.kubeconfig

kubectl config set-cluster kubernetes \
  --embed-certs=false \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes \
  --user="" \
  --kubeconfig=kube-proxy.kubeconfig

# 设置默认上下文
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
