export KUBECONFIG=/vagrant/artifacts/kubeconfig
# install gateway api crds first
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.3.0" | kubectl apply -f -

# install nginx gateway fabric with helm
#
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway

# wait for nginx gateway fabric pods to be ready
kubectl wait --timeout=5m -n nginx-gateway deployment/ngf-nginx-gateway-fabric --for=condition=Available

echo "[50-network-gw] verify the gateway api is installed in the cluster"
kubectl get pods -n nginx-gateway
kubectl get gatewayclass
