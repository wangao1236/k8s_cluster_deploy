#!/bin/bash

ETCD_SERVERS=$1
APISERVER=$2

cat <<EOF >config
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
KUBE_LOGTOSTDERR="--logtostderr=true"
 
# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"
 
# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=false"
 
# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=http://$APISERVER:8443"
EOF

cat <<EOF >apiserver
###
# kubernetes system config
#
# The following values are used to configure the kube-apiserver
#
# The address on the local server to listen to.
KUBE_API_ADDRESS="--insecure-bind-address=0.0.0.0"

# The port on the local server to listen on.
# KUBE_API_PORT="--port=8080"

# Port minions listen on
# KUBELET_PORT="--kubelet-port=10250"

# Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=${ETCD_SERVERS} \\
    --etcd-cafile=/opt/etcd/ssl/ca.pem \\
    --etcd-certfile=/opt/etcd/ssl/server.pem \\
    --etcd-keyfile=/opt/etcd/ssl/server-key.pem"

# Address range to use for services
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"

# default admission control policies
#KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota"
KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota"

# Add your own!
KUBE_API_ARGS=""
EOF

cat <<EOF >controller-manager
###
# The following values are used to configure the kubernetes controller-manager
 
# defaults from config and apiserver should be adequate
 
# Add your own!
KUBE_CONTROLLER_MANAGER_ARGS=""
EOF

cat <<EOF >scheduler
###
# kubernetes scheduler config
 
# default config should be adequate
 
# Add your own!
KUBE_SCHEDULER_ARGS="--loglevel=0"
EOF

cat <<EOF >kubelet
###
# kubernetes kubelet (minion) config
 
# The address for the info server to serve on (set to 0.0.0.0 or "" for all interfaces)
# KUBELET_ADDRESS="--address=127.0.0.1"
 
# The port for the info server to serve on
KUBELET_PORT="--port=10250"
 
# You may leave this blank to use the actual hostname
# KUBELET_HOSTNAME="--hostname-override=127.0.0.1"
 
# location of the api-server
##KUBELET_API_SERVER="--api-servers=http://127.0.0.1:8080"
 
# pod infrastructure container
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=docker.io/kubernetes/pause"
 
# Add your own!
KUBELET_ARGS="--fail-swap-on=false --cgroup-driver=cgroupfs --kubeconfig=/var/lib/kubelet/kubeconfig"
EOF

cat <<EOF >proxy
###
# kubernetes proxy config
 
# default config should be adequate
 
# Add your own!
KUBE_PROXY_ARGS=""
EOF
