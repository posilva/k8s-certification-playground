# Vagrant kubernetes cluster for CKA preparation

List taints in nodes
`kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints`

# create a user for testing RBAC

- `sudo useradd -m -s /bin/bash -G sudo testuser`
- sudo passwd testuser
- sudo -i -u testuser

# create the private key

- openssl genrsa -out testuser.key 2048
- openssl req -new -key testuser.key -out testuser.csr -subj "/CN=testuser/O=k8s"
- sudo openssl x509 -req -in testuser.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out testuser.crt -days 365

# configure kubectl for the testuser

- mkdir -p /home/testuser/.kube
- sudo cp /etc/kubernetes/admin.conf /home/testuser/.kube/config
- sudo chown testuser:testuser /home/testuser/.kube/config

# add the user credentials to config

- kubectl config set-credentials testuser --client-certificate=testuser.crt --client-key=testuser.key --kubeconfig=/home/testuser/.kube/config

# check the existing contexts in the cluster (copy the cluster name )

- kubectl config get-contexts

# create a context for the user

- kubectl config set-context testuser-context --cluster=vagrant-k8s --namespace=default --user=testuser --kubeconfig=/home/testuser/.kube/config

- kubectl config use-context testuser-context

# try to list pods with the user (should return forvidden)

- kubectl get pods

# create a role for a staff to bind later totest user

- kubectl create role staff -n staff --verb=get,list,watch,create,update,patch,delete --resource=deployments,pods,replicasets,services
- kubectl create rolebinding -n staff staff-role-binding --user=testuser --role=staff

# clustername is defined in coreDNS configmap Corefile entry

- kubectl -n kube-system get configmap coredns -o yaml

# run a simple service and exposed as a service

kubectl run webserver --image=nginx --replicas=2
kubectl expose pod webserver --port=80
kubectl run shellpod --image=busybox --command -- sleep 3600
kubectl exec -it shellpod -- wget webserver
