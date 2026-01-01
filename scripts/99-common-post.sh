sudo -u vagrant -H bash -lc '
  mkdir -p ~/.kube
  cp /vagrant/artifacts/kubeconfig ~/.kube/config
  chmod 600 ~/.kube/config
  chown $(id -u):$(id -g) ~/.kube/config
  echo "alias k=kubectl" >>~/.bashrc
  echo "source <(kubectl completion bash)" >>~/.bashrc
  echo "source <(kubeadm completion bash)" >>~/.bashrc
  echo "source <(helm completion bash)" >>~/.bashrc
  source ~/.bashrc
'
