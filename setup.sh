#!/bin/bash
# ============================================================
# MikroCsirip - Telepito szkript
# Ubuntu 22.04 / 24.04 LTS
# Hasznalat: chmod +x setup.sh && ./setup.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}>> $1${NC}"; }
warn() { echo -e "${YELLOW}!! $1${NC}"; }
error() { echo -e "${RED}XX $1${NC}"; exit 1; }
section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE} $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

if [ "$EUID" -eq 0 ]; then
 error "Ne futtasd root-kent! Futtasd sima felhasznalokent: ./setup.sh"
fi

CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── MicroK8s csoport ellenorzese ─────────────────────────────
# Ha microk8s telepítve van de nincs csoport jogosultság,
# hozzáadjuk a felhasználót és sg-vel újraindítjuk a scriptet
if command -v microk8s &>/dev/null && ! groups | grep -q microk8s; then
 echo -e "${YELLOW}>> MicroK8s csoport hozzaadasa: $CURRENT_USER${NC}"
 sudo usermod -aG microk8s $CURRENT_USER
 sudo chown -R $CURRENT_USER ~/.kube 2>/dev/null || true
 echo -e "${GREEN}>> Ujrainditás microk8s session-nel...${NC}"
 exec sg microk8s -c "bash \"$0\" \"$@\""
fi

DEFAULT_PROJECT_DIR="$SCRIPT_DIR"
DEFAULT_NAMESPACE="mikrocsirip"
DEFAULT_SQL_PASSWORD="MikroCsirip123!"
DEFAULT_JWT_KEY="MikroCsiripJwtSecretKey32CharsMin!!"
DEFAULT_API_PORT=8081
DEFAULT_FRONTEND_PORT=4200

section "MikroCsirip Telepito - Konfiguracío"
echo -e "${YELLOW}Nyomj ENTER-t az alapertelmezett ertekek elfogadasahoz.${NC}"
echo ""

read -p " Projekt mappa [$DEFAULT_PROJECT_DIR]: " INPUT_PROJECT_DIR
PROJECT_DIR="${INPUT_PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"

read -p " Kubernetes namespace [$DEFAULT_NAMESPACE]: " INPUT_NAMESPACE
NAMESPACE="${INPUT_NAMESPACE:-$DEFAULT_NAMESPACE}"

read -p " SQL Server jelszo [$DEFAULT_SQL_PASSWORD]: " INPUT_SQL_PASSWORD
SQL_PASSWORD="${INPUT_SQL_PASSWORD:-$DEFAULT_SQL_PASSWORD}"

read -p " JWT Secret Key [$DEFAULT_JWT_KEY]: " INPUT_JWT_KEY
JWT_KEY="${INPUT_JWT_KEY:-$DEFAULT_JWT_KEY}"

read -p " API port [$DEFAULT_API_PORT]: " INPUT_API_PORT
API_PORT="${INPUT_API_PORT:-$DEFAULT_API_PORT}"

read -p " Frontend port [$DEFAULT_FRONTEND_PORT]: " INPUT_FRONTEND_PORT
FRONTEND_PORT="${INPUT_FRONTEND_PORT:-$DEFAULT_FRONTEND_PORT}"

echo ""
echo -e "${BLUE}----------------------------------------${NC}"
echo -e " Felhasznalo : $CURRENT_USER"
echo -e " Projekt : $PROJECT_DIR"
echo -e " Namespace : $NAMESPACE"
echo -e " SQL jelszo : $SQL_PASSWORD"
echo -e " JWT kulcs : $JWT_KEY"
echo -e " API port : $API_PORT"
echo -e " Frontend : $FRONTEND_PORT"
echo -e "${BLUE}----------------------------------------${NC}"
echo ""
read -p "Folytatod a telepitesi? [I/n]: " CONFIRM
CONFIRM="${CONFIRM:-I}"
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
 echo "Telepites megszakitva."
 exit 0
fi

# ── 1. Rendszer frissites ────────────────────────────────────
section "1/6 Rendszer frissitese"
sudo apt-get update -qq
sudo apt-get install -y -qq \
 curl wget git apt-transport-https \
 ca-certificates gnupg lsb-release \
 python3-pip jq snapd

# ── 2. Docker telepites ──────────────────────────────────────
section "2/6 Docker telepitese"
if command -v docker &>/dev/null; then
 log "Docker mar telepitve: $(docker --version)"
else
 log "Docker telepitese..."
 curl -fsSL https://get.docker.com | sudo sh
 sudo usermod -aG docker $CURRENT_USER
fi

sudo chmod 666 /var/run/docker.sock
mkdir -p ~/.docker
cat > ~/.docker/config.json << 'DOCKEREOF'
{
 "credsStore": ""
}
DOCKEREOF

# Docker insecure registry beallitasa
DOCKER0_IP=$(ip addr show docker0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "172.17.0.1")
log "Docker0 IP: $DOCKER0_IP"

if ! grep -q "insecure-registries" /etc/docker/daemon.json 2>/dev/null; then
 echo "{\"insecure-registries\":[\"${DOCKER0_IP}:5000\",\"localhost:5000\",\"127.0.0.1:5000\"]}" | \
 sudo tee /etc/docker/daemon.json > /dev/null
 sudo systemctl restart docker
 sleep 5
fi
sudo chmod 666 /var/run/docker.sock

# ── 3. MicroK8s telepites ────────────────────────────────────
section "3/6 MicroK8s telepitese"
if command -v microk8s &>/dev/null; then
 log "MicroK8s mar telepitve"
else
 log "MicroK8s telepitese..."
 sudo snap install microk8s --classic
 sudo usermod -aG microk8s $CURRENT_USER
 sudo chown -R $CURRENT_USER ~/.kube 2>/dev/null || true
 log "Ujrainditás microk8s session-nel..."
 exec sg microk8s -c "bash \"$0\" \"$@\""
fi

# Ha van microk8s de nincs csoport jogosultsag
if ! groups | grep -q microk8s; then
 log "MicroK8s csoport hozzaadasa..."
 sudo usermod -aG microk8s $CURRENT_USER
 sudo chown -R $CURRENT_USER ~/.kube 2>/dev/null || true
 exec sg microk8s -c "bash \"$0\" \"$@\""
fi

sudo chmod -R o-rwX /var/snap/microk8s/current/credentials/ 2>/dev/null || true
sudo chown -R root:microk8s /var/snap/microk8s/current/credentials/ 2>/dev/null || true

# MicroK8s inditasa
log "MicroK8s inditasa..."
microk8s start
log "Varakozas a MicroK8s indulasara..."
microk8s status --wait-ready --timeout 120

# Addons bekapcsolasa
log "MicroK8s addons bekapcsolasa..."
microk8s enable dns storage registry

# microk8s kubectl alias beallitasa
mkdir -p ~/.kube
microk8s config > ~/.kube/config
sudo chown $CURRENT_USER:$CURRENT_USER ~/.kube/config
grep -qxF 'export KUBECONFIG=~/.kube/config' ~/.bashrc || \
 echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
export KUBECONFIG=~/.kube/config

log "MicroK8s fut"

# ── 4. .NET SDK telepites ────────────────────────────────────
section "4/6 .NET 8 SDK telepitese"
if dotnet --version 2>/dev/null | grep -qE "^[89]|^10"; then
 log ".NET mar telepitve: $(dotnet --version)"
else
 log ".NET 8 SDK telepitese..."
 wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" \
 -O /tmp/packages-microsoft-prod.deb
 sudo dpkg -i /tmp/packages-microsoft-prod.deb
 sudo apt-get update -qq
 sudo apt-get install -y -qq dotnet-sdk-8.0
fi

if ! dotnet tool list -g 2>/dev/null | grep -q dotnet-ef; then
 dotnet tool install --global dotnet-ef
fi
export PATH="$PATH:$HOME/.dotnet/tools"
grep -qxF 'export PATH="$PATH:$HOME/.dotnet/tools"' ~/.bashrc || \
 echo 'export PATH="$PATH:$HOME/.dotnet/tools"' >> ~/.bashrc

# ── 5. Node.js + Angular CLI ────────────────────────────────
section "5/6 Node.js es Angular CLI telepitese"
if command -v node &>/dev/null; then
 log "Node.js mar telepitve: $(node --version)"
else
 curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
 sudo apt-get install -y -qq nodejs
fi

if ! command -v ng &>/dev/null; then
 sudo npm install -g @angular/cli --silent
fi

# ── 6. Ansible telepites es deploy ──────────────────────────
section "6/6 Ansible telepitese es deploy inditasa"

export PATH="$PATH:$HOME/.local/bin"

if ! command -v ansible-playbook &>/dev/null; then
 sudo apt-get install -y -qq software-properties-common
 sudo apt-add-repository -y ppa:ansible/ansible 2>/dev/null || true
 sudo apt-get update -qq
 sudo apt-get install -y -qq ansible
fi

log "Ansible: $(ansible --version | head -1)"

# MicroK8s registry IP lekerdezese
REGISTRY_IP=$(sudo microk8s kubectl get svc registry -n container-registry \
 -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -z "$REGISTRY_IP" ]; then
 REGISTRY_IP="localhost"
fi
REGISTRY_HOST="${REGISTRY_IP}:5000"
log "MicroK8s registry: $REGISTRY_HOST"

# Ansible vars generalasa
log "Ansible valtozok generalasa..."
cat > "$PROJECT_DIR/ansible/group_vars/local.yml" << VARSEOF
---
env: local
registry_host: "localhost:32000"
image_tag: "latest"
k8s_namespace: "$NAMESPACE"
sql_sa_password: "$SQL_PASSWORD"
sql_db_name: "mikrocsirip"
sql_port: 1433
jwt_key: "$JWT_KEY"
jwt_issuer: "MikroCsirip"
jwt_audience: "MikroCsiripUsers"
api_replicas: 1
frontend_replicas: 1
api_port: $API_PORT
frontend_port: $FRONTEND_PORT
ingress_ip: "$INGRESS_IP"
project_root: "$PROJECT_DIR"
VARSEOF

cat > "$PROJECT_DIR/ansible/ansible.cfg" << 'CFGEOF'
[defaults]
roles_path = ./roles
inventory = ./inventory/hosts
host_key_checking = False
CFGEOF

mkdir -p "$PROJECT_DIR/ansible/inventory"
cat > "$PROJECT_DIR/ansible/inventory/hosts" << 'HOSTSEOF'
[local]
localhost ansible_connection=local
HOSTSEOF

# NOPASSWD sudo
cat << SUDOEOF | sudo tee /etc/sudoers.d/mikrocsirip-ansible > /dev/null
$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/tee, /bin/systemctl, /usr/bin/systemctl, /bin/chmod, /usr/bin/chmod, /usr/bin/microk8s, /snap/bin/microk8s
SUDOEOF
sudo chmod 440 /etc/sudoers.d/mikrocsirip-ansible

log "Ansible deploy inditasa..."
cd "$PROJECT_DIR/ansible"

ANSIBLE_CMD=$(which ansible-playbook)
sg microk8s -c "$ANSIBLE_CMD playbooks/deploy-local.yml \
 -e \"project_root=$PROJECT_DIR\" \
 -e \"api_port=$API_PORT\" \
 -e \"frontend_port=$FRONTEND_PORT\""

# Start-stop szkript generalasa
cat > "$HOME/start-mikrocsirip.sh" << STARTEOF
#!/bin/bash
export KUBECONFIG=~/.kube/config
export PATH="\$PATH:\$HOME/.dotnet/tools:\$HOME/.local/bin"
cd $PROJECT_DIR
./mikrocsirip.sh start
STARTEOF
chmod +x "$HOME/start-mikrocsirip.sh"

section "Telepites kesz!"
echo ""
echo -e " ${GREEN}Frontend : http://localhost:$FRONTEND_PORT${NC}"
echo -e " ${GREEN}API : http://localhost:$API_PORT/api${NC}"
echo -e " ${GREEN}Swagger : http://localhost:$API_PORT/swagger${NC}"
echo ""
echo -e " Inditas: ${YELLOW}./mikrocsirip.sh start${NC}"
echo -e " Leallitas: ${YELLOW}./mikrocsirip.sh stop${NC}"
