#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR="/vagrant/artifacts"
JOIN_SCRIPT="${ARTIFACT_DIR}/join.sh"

echo "[20-worker] Starting worker join procedure..."

# If node is already joined, exit cleanly (idempotent)
if [[ -f /etc/kubernetes/kubelet.conf ]]; then
  echo "[20-worker] Node already appears joined (/etc/kubernetes/kubelet.conf exists). Exiting."
  exit 0
fi

echo "[20-worker] Waiting for ${JOIN_SCRIPT} to exist..."
for _ in {1..240}; do
  if [[ -s "${JOIN_SCRIPT}" ]]; then
    break
  fi
  sleep 2
done

if [[ ! -s "${JOIN_SCRIPT}" ]]; then
  echo "ERROR: join script not found after waiting: ${JOIN_SCRIPT}"
  echo "Ensure control plane finished and wrote /vagrant/artifacts/join.sh"
  exit 1
fi

echo "[20-worker] Verifying containerd is running..."
systemctl is-active --quiet containerd || (systemctl status containerd --no-pager && exit 1)

echo "[20-worker] Verifying CRI socket exists..."
if [[ ! -S /run/containerd/containerd.sock ]]; then
  echo "ERROR: /run/containerd/containerd.sock not found."
  exit 1
fi

echo "[20-worker] Joining cluster using ${JOIN_SCRIPT}..."
bash "${JOIN_SCRIPT}"

# Post-join: ensure kubelet is running
echo "[20-worker] Ensuring kubelet is running..."
systemctl enable kubelet >/dev/null 2>&1 || true
systemctl restart kubelet >/dev/null 2>&1 || true

cp /vagrant/manifests/staticpod.yaml /etc/kubernetes/manifests/
echo "[20-worker] Join complete."
