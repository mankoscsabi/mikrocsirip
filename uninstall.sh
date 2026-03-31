#!/bin/bash
# ============================================================
# MikroCsirip - Eltavolito szkript
# Hasznalat: chmod +x uninstall.sh && ./uninstall.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}>> $1${NC}"; }
warn() { echo -e "${YELLOW}!! $1${NC}"; }
section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE} $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

if [ "$EUID" -eq 0 ]; then
 echo -e "${RED}Ne futtasd root-kent!${NC}"; exit 1
fi

NAMESPACE="mikrocsirip"

section "MikroCsirip Eltavolito"
echo -e "${YELLOW}Ez a szkript eltavolitja a MikroCsirip alkalmazast.${NC}"
echo ""
echo " Mit tavolit el:"
echo " - Kubernetes namespace es minden eroforras"
echo " - Docker image-ek"
echo " - Port-forward folyamatok"
echo ""

read -p "Toroljuk a telepitett eszkozoket is? (MicroK8s, Docker, .NET, Node.js) [i/N]: " DELETE_TOOLS
DELETE_TOOLS="${DELETE_TOOLS:-N}"

echo ""
echo -e "${RED}FIGYELEM: Ez a muvelet nem visszavonhato!${NC}"
read -p "Biztosan folytatod? [i/N]: " CONFIRM
CONFIRM="${CONFIRM:-N}"
if [[ ! "$CONFIRM" =~ ^[Ii]$ ]]; then
 echo "Megszakitva."
 exit 0
fi

# ── 1. Port-forward leallitasa ───────────────────────────────
section "1/4 Port-forward leallitasa"
pkill -f "microk8s kubectl port-forward svc/mikrocsirip" 2>/dev/null && log "Leallitva" || log "Nem volt futo port-forward"

# ── 2. Kubernetes eroforrasok torlese ────────────────────────
section "2/4 Kubernetes eroforrasok torlese"
export KUBECONFIG=~/.kube/config

if microk8s status 2>/dev/null | grep -q "microk8s is running"; then
 if microk8s kubectl get namespace $NAMESPACE &>/dev/null 2>&1; then
 log "Namespace torlese: $NAMESPACE"
 microk8s kubectl delete namespace $NAMESPACE --timeout=60s 2>/dev/null || true
 else
 log "Namespace nem letezett"
 fi
else
 warn "MicroK8s nem fut - namespace torles kihagyva"
fi

# ── 3. Docker image-ek torlese ───────────────────────────────
section "3/4 Docker image-ek torlese"
log "MikroCsirip image-ek torlese..."
docker rmi -f $(docker images | grep "mikrocsirip" | awk '{print $3}') 2>/dev/null || true
log "Image-ek torolve"

# ── 4. Eszkozok eltavolitasa (opcionalis) ────────────────────
section "4/4 Eszkozok eltavolitasa"

if [[ "$DELETE_TOOLS" =~ ^[Ii]$ ]]; then
 warn "MicroK8s eltavolitasa..."
 sudo snap remove microk8s --purge 2>/dev/null || true

 warn "Docker eltavolitasa..."
 sudo apt-get remove -y docker-ce docker-ce-cli containerd.io 2>/dev/null || true
 sudo apt-get autoremove -y 2>/dev/null || true

 warn ".NET eltavolitasa..."
 sudo apt-get remove -y dotnet-sdk-8.0 2>/dev/null || true
 dotnet tool uninstall --global dotnet-ef 2>/dev/null || true

 warn "Node.js eltavolitasa..."
 sudo apt-get remove -y nodejs 2>/dev/null || true

 warn "Ansible eltavolitasa..."
 sudo apt-get remove -y ansible 2>/dev/null || true

 log "Eszkozok eltavolitva"
else
 log "Eszkozok megmaradnak"
fi

# Konfiguracios fajlok torlese
log "Konfiguracios fajlok torlese..."
rm -f ~/start-mikrocsirip.sh
rm -f /tmp/mikrocsirip-*.log
sudo rm -f /etc/sudoers.d/mikrocsirip-ansible

section "Eltavolitas kesz!"
echo ""
echo " Eltavolitva:"
echo " - Kubernetes namespace ($NAMESPACE)"
echo " - Docker image-ek"
[[ "$DELETE_TOOLS" =~ ^[Ii]$ ]] && echo " - Telepitett eszkozok"
echo ""
echo -e " A projekt fajlok megmaradtak: ${YELLOW}~/mikrocsirip${NC}"
echo -e " Ujratelepiteshez: ${YELLOW}./setup.sh${NC}"
