
#!/usr/bin/env bash
set -Eeuo pipefail

# ==========================================
# Kubernetes Lab Bootstrap
# Docker + kubectl + Kind
# 1 Control Plane + 2 Worker Nodes
# ==========================================

CLUSTER_NAME="${CLUSTER_NAME:-k8s-lab}"
K8S_VERSION="${K8S_VERSION:-v1.33.0}"
KIND_VERSION="${KIND_VERSION:-latest}"
WORKERS="${WORKERS:-2}"

log()  { echo -e "\n[INFO] $*"; }
warn() { echo -e "\n[WARN] $*" >&2; }
fail() { echo -e "\n[ERROR] $*" >&2; exit 1; }

trap 'fail "Setup failed at line $LINENO. Check the error above."' ERR

# Require Linux
[[ "$(uname -s)" == "Linux" ]] || fail "Linux is required."

# Determine architecture
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) fail "Unsupported architecture: $ARCH" ;;
esac

# Require sudo when not root
if [[ "$EUID" -eq 0 ]]; then
  SUDO=""
  TARGET_USER="${SUDO_USER:-root}"
else
  command -v sudo >/dev/null 2>&1 || fail "Install sudo or run as root."
  SUDO="sudo"
  TARGET_USER="$USER"
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[[ -n "$TARGET_HOME" ]] || fail "Could not determine user home."

export KUBECONFIG="$TARGET_HOME/.kube/config"

# ------------------------------------------
# Install basic dependencies
# ------------------------------------------

install_packages() {
  local packages=(curl ca-certificates tar gzip)

  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -y
    $SUDO apt-get install -y "${packages[@]}" gnupg
  elif command -v dnf >/dev/null 2>&1; then
    $SUDO dnf install -y "${packages[@]}" gnupg2
  elif command -v yum >/dev/null 2>&1; then
    $SUDO yum install -y "${packages[@]}" gnupg2
  elif command -v pacman >/dev/null 2>&1; then
    $SUDO pacman -Sy --noconfirm "${packages[@]}" gnupg
  elif command -v zypper >/dev/null 2>&1; then
    $SUDO zypper --non-interactive install "${packages[@]}" gpg2
  else
    fail "Unsupported package manager. Install curl, tar and gzip manually."
  fi
}

log "Checking system dependencies..."
install_packages

# ------------------------------------------
# Install Docker if missing
# ------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine using Docker's official installer..."
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  $SUDO sh /tmp/get-docker.sh
  rm -f /tmp/get-docker.sh
else
  log "Docker already installed."
fi

# Start Docker where systemd is available
if command -v systemctl >/dev/null 2>&1; then
  $SUDO systemctl enable --now docker || {
    warn "Could not start Docker through systemd."
  }
fi

command -v docker >/dev/null 2>&1 || fail "Docker CLI unavailable."

# Add user to Docker group if required
if [[ "$EUID" -ne 0 ]] &&
   ! docker info >/dev/null 2>&1; then

  if getent group docker >/dev/null 2>&1; then
    log "Adding $TARGET_USER to Docker group..."
    $SUDO usermod -aG docker "$TARGET_USER"
  else
    fail "Docker daemon is inaccessible and docker group is missing."
  fi
fi

# ------------------------------------------
# Install kubectl if missing
# ------------------------------------------

if ! command -v kubectl >/dev/null 2>&1; then
  log "Installing kubectl..."

  KUBECTL_VERSION="$(
    curl -fsSL https://dl.k8s.io/release/stable.txt
  )"

  curl -fsSLO \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"

  curl -fsSLO \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"

  echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check \
    || fail "kubectl checksum verification failed."

  $SUDO install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  rm -f kubectl kubectl.sha256
else
  log "kubectl already installed."
fi

# ------------------------------------------
# Install Kind if missing
# ------------------------------------------

if ! command -v kind >/dev/null 2>&1; then
  log "Installing Kind..."

  if [[ "$KIND_VERSION" == "latest" ]]; then
    KIND_URL="https://kind.sigs.k8s.io/dl/latest/kind-linux-${ARCH}"
  else
    KIND_URL="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  fi

  curl -fsSL "$KIND_URL" -o /tmp/kind
  $SUDO install -o root -g root -m 0755 /tmp/kind /usr/local/bin/kind
  rm -f /tmp/kind
else
  log "Kind already installed."
fi

# ------------------------------------------
# Verify binaries
# ------------------------------------------

log "Installed versions:"
docker --version
kubectl version --client
kind version

# ------------------------------------------
# Prepare Kind configuration
# ------------------------------------------

mkdir -p "$TARGET_HOME/.kube"
chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$TARGET_HOME/.kube"
chmod 700 "$TARGET_HOME/.kube"

CONFIG_FILE="$(mktemp)"

cat > "$CONFIG_FILE" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF

# ------------------------------------------
# Create cluster if missing
# ------------------------------------------

if kind get clusters 2>/dev/null | grep -Fxq "$CLUSTER_NAME"; then
  log "Cluster '$CLUSTER_NAME' already exists. Skipping creation."
else
  log "Creating Kubernetes cluster: $CLUSTER_NAME"

  # Use Docker group membership immediately if it was just added.
  if [[ "$EUID" -ne 0 ]] &&
     ! docker info >/dev/null 2>&1; then

    sg docker -c \
      "KUBECONFIG='$KUBECONFIG' kind create cluster \
      --name '$CLUSTER_NAME' \
      --image 'kindest/node:${K8S_VERSION}' \
      --config '$CONFIG_FILE' \
      --wait 180s"
  else
    kind create cluster \
      --name "$CLUSTER_NAME" \
      --image "kindest/node:${K8S_VERSION}" \
      --config "$CONFIG_FILE" \
      --wait 180s
  fi
fi

rm -f "$CONFIG_FILE"

# ------------------------------------------
# Fix kubeconfig ownership
# ------------------------------------------

if [[ -f "$KUBECONFIG" ]]; then
  $SUDO chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$KUBECONFIG"
  chmod 600 "$KUBECONFIG"
fi

# ------------------------------------------
# Validate cluster
# ------------------------------------------

log "Checking Kubernetes cluster..."

kubectl cluster-info
kubectl get nodes -o wide

log "Kubernetes lab setup completed successfully."
log "Cluster: $CLUSTER_NAME"
log "Workers: $WORKERS"
log "Kubeconfig: $KUBECONFIG"

echo
echo "Useful commands:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl get namespaces"
echo "  kind get clusters"
echo "  kind delete cluster --name $CLUSTER_NAME"
