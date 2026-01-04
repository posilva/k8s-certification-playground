#!/usr/bin/env bash

set -euo pipefail

# the ip passed as first parameter to this script
NODE_IP="${1:-}"

if [[ -z "${NODE_IP}" ]]; then
  echo "ERROR: expected node IP missing as first paramter"
  echo "Usage: $0 <NODE_IP>"
  exit 1
fi

VM_USER="${2:-}"
VM_PASS="${3:-}"

if [[ -n "${VM_USER}" && -n "${VM_PASS}" ]]; then
  echo "[00-common] Ensuring admin user exists: ${VM_USER}"
  if ! id -u "${VM_USER}" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "${VM_USER}"
  fi

  echo "${VM_USER}:${VM_PASS}" | chpasswd
  usermod -aG sudo "${VM_USER}"

fi

# latest version at this time in: https://kubernetes.io/releases/
K8S_MINOR="${K8S_MINOR:-1.35}"

echo "[00-common] Starting commo node preparation (NODE_IP=${NODE_IP}) and Kubernetes version=${K8S_MINOR})"

# disable swap
swapoff -a || true

# comment all the configurations in /etc/fstab that may enable swap on reboot
if grep -Eqs '^\s*[^#].*\s+swap\s' /etc/fstab; then
  sed -i.bak -r 's/^(\s*[^#].*\s+swap\s+.*)$/# \1/g' /etc/fstab
fi

echo "[00-common] Configuring kernel modules and sysctl..."
cat >/etc/modules-load.d/k8s.conf <<'EOF'
overlay
br_netfilter
EOF

modprobe overlay || true
modprobe br_netfilter || true

cat >/etc/sysctl.d/k8s.conf <<'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
net.ipv6.ip_forward                 = 1
EOF

sysctl --system >/dev/null

echo "[00-common] Installing base packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gpg \
  apt-transport-https \
  software-properties-common \
  socat \
  conntrack \
  ebtables \
  ethtool \
  iproute2 \
  iptables \
  bash-completion \
  chrony

# enable the NTP service
systemctl enable --now chrony >/dev/null 2>&1 || true

# Remove distro containerd if present
apt-get remove -y containerd || true

# Add Docker apt repo (for containerd.io)
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

. /etc/os-release

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  ${VERSION_CODENAME} stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

apt-get update -y

echo "[00-common] Installing containerd..."

apt-get install -y --no-install-recommends containerd.io=2.2.0-2~${ID}.${VERSION_ID}~${VERSION_CODENAME}

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml

# 1) Force-enable CRI (some package defaults disable it)
# Kubernetes docs: ensure CRI is not listed in disabled_plugins. :contentReference[oaicite:3]{index=3}
if grep -qE '^\s*disabled_plugins\s*=' /etc/containerd/config.toml; then
  sed -i -E 's/^\s*disabled_plugins\s*=.*$/disabled_plugins = []/' /etc/containerd/config.toml
else
  # If not present, add an explicit empty list near the top (safe)
  sed -i '1i disabled_plugins = []\n' /etc/containerd/config.toml
fi

sed -i -r 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

PAUSE_IMAGE="${PAUSE_IMAGE:-registry.k8s.io/pause:3.10.1}"
if grep -qE '^\s*sandbox_image\s*=' /etc/containerd/config.toml; then
  sed -i -E "s#(^\s*sandbox_image\s*=\s*\").*(\".*)#\1${PAUSE_IMAGE}\2#g" /etc/containerd/config.toml
fi

systemctl daemon-reload
systemctl enable --now containerd
systemctl restart containerd

echo "[00-common] containerd version: $(containerd --version || true)"
echo "[00-common] Checking CRI plugin status..."
ctr plugins ls | awk 'NR==1 || /cri/ || /runtime/ {print}'

cat >/etc/crictl.yaml <<'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: ""
timeout: 10
debug: false
EOF

echo "[00-common] Installing kubeadm/kubelet/kubectl (K8S_MINOR=${K8S_MINOR})..."
mkdir -p /etc/apt/keyrings

curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key" |
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/ /
EOF

apt-get update -y
apt-get install -y --no-install-recommends kubelet kubeadm kubectl

# Prevent unintended upgrades during 'apt upgrade'
apt-mark hold kubelet kubeadm kubectl

echo "[00-common] Configuring kubelet node IP..."
mkdir -p /etc/default

# overwrite safely (simple and deterministic)
cat >/etc/default/kubelet <<EOF
KUBELET_EXTRA_ARGS=--node-ip=${NODE_IP}
EOF

systemctl enable kubelet
systemctl restart kubelet >/dev/null 2>&1 || true

snap install jq || true
snap install yq || true
snap install helm --classic || true

echo "[00-common] Done."
echo "[00-common] containerd: $(containerd --version || true)"
echo "[00-common] kubeadm:     $(kubeadm version -o short || true)"
echo "[00-common] kubelet:     $(kubelet --version || true)"
