# k8s_cluster_deploy

+ 多节点集群部署 k8s 集群的相关脚本和文件
+ 使用 haproxy+keepalived 或者 Nginx 实现 Master 节点负载均衡，各个 Master 节点上均部署一个 Node
+ scripts 为文章 [Kubernetes 二进制部署（二）集群部署（多 Master 节点通过 Nginx 负载均衡）](https://www.cnblogs.com/wangao1236/p/12334914.html) 所使用的脚本
+ nginx 文件夹存放 Nginx 组件实现负载均衡的配置文件
+ haproxy 存在 haproxy+keepalived 实现负载均衡的 haproxy 配置文件
+ keepalived 存放 haproxy+keepalived 实现负载均衡的 keeplived 配置文件
+ yamls 存放各个测试的 kubernetes 配置文件

