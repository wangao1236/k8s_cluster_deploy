kubectl delete -f kube-flannel.yml
kubectl delete -f nginx-deployment.yaml
kubectl apply -f kube-flannel.yml
kubectl apply -f nginx-deployment.yaml
