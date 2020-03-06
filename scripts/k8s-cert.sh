rm -rf master
rm -rf node
mkdir master
mkdir node

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
    "CN": "admin",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "system:masters",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

#----------------------- kube-apiserver

echo "generate kube-apiserver cert"

cd master

cat > kube-apiserver-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [
      "127.0.0.1",
      "192.168.1.99",
      "192.168.1.65",
      "192.168.1.67",
      "192.168.1.68",
      "192.168.1.69",
      "10.254.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=kubernetes kube-apiserver-csr.json | cfssljson -bare kube-apiserver

cd ..

#----------------------- kubectl

echo "generate kubectl cert"

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [
      "127.0.0.1",
      "192.168.1.99",
      "192.168.1.65",
      "192.168.1.67",
      "192.168.1.68",
      "192.168.1.69",
      "10.254.0.1",
      "kubernetes",
      "kubernetes.default",
      "kubernetes.default.svc",
      "kubernetes.default.svc.cluster",
      "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

#----------------------- kube-controller-manager

echo "generate kube-controller-manager cert"

cd master

cat > kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "192.168.1.67",
      "192.168.1.68",
      "192.168.1.69"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing",
            "O": "system:kube-controller-manager",
            "OU": "System"
        }
    ]
}
EOF


cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

cd ..

#----------------------- kube-scheduler

echo "generate kube-scheduler cert"

cd master

cat > kube-scheduler-csr.json <<EOF
{
    "CN": "system:kube-scheduler",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "192.168.1.67",
      "192.168.1.68",
      "192.168.1.69"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing",
            "O": "system:kube-scheduler",
            "OU": "System"
        }
    ]
}
EOF


cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler

cd ..

#----------------------- kube-proxy

echo "generate kube-proxy cert"

cd node

cat > kube-proxy-csr.json <<EOF
{
    "CN": "system:kube-proxy",
    "hosts": [],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing",
            "O": "system:kube-proxy",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy

cd ..

#----------------------- kubelet

echo "generate kubelet cert"

cd node

for instance in node1 node2 node3; do
cat > ${instance}-csr.json <<EOF
{
    "CN": "system:node:${instance}",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
        "127.0.0.1",
        "192.168.1.67",
        "192.168.1.68",
        "192.168.1.69",
        "${instance}"
    ],
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "system:nodes",
            "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=../ca.pem -ca-key=../ca-key.pem -config=../ca-config.json -profile=kubernetes ${instance}-csr.json | cfssljson -bare ${instance}
done

cd ..
