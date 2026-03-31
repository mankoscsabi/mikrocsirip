#!/bin/bash
# ============================================================
# MikroCsirip - Fő kezelő szkript
# Hasznalat: ./mikrocsirip.sh [parancs]
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}>> $1${NC}"; }
warn() { echo -e "${YELLOW}!! $1${NC}"; }
error() { echo -e "${RED}XX $1${NC}"; exit 1; }
section() { echo -e "\n${BLUE}========================================${NC}"; echo -e "${BLUE} $1${NC}"; echo -e "${BLUE}========================================${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export KUBECONFIG=~/.kube/config
export PATH="$PATH:$HOME/.local/bin:$HOME/.dotnet/tools"

NAMESPACE="mikrocsirip"
API_PORT="${API_PORT:-8081}"
FRONTEND_PORT="${FRONTEND_PORT:-4200}"

# ── MicroK8s kezelés ─────────────────────────────────────────

microk8s_check_group() {
 if ! groups | grep -q microk8s; then
 warn "MicroK8s csoport jogosultsag hianzik - hozzaadas..."
 sudo usermod -aG microk8s $USER
 sudo chown -R $USER ~/.kube 2>/dev/null || true
 warn "Uj session inditasa a jogosultsaggal..."
 exec sg microk8s -c "bash $0 $1"
 fi
}

microk8s_start_wait() {
 microk8s_check_group
 if ! microk8s status 2>/dev/null | grep -q "microk8s is running"; then
 log "MicroK8s inditasa..."
 microk8s start
 fi
 log "Varakozas a MicroK8s indulasara..."
 microk8s status --wait-ready --timeout 120
 mkdir -p ~/.kube
 microk8s config > ~/.kube/config
}

# ── Parancsok ────────────────────────────────────────────────

usage() {
 section "MikroCsirip - Hasznalat"
 echo ""
 echo -e " ${YELLOW}./mikrocsirip.sh [parancs]${NC}"
 echo ""
 echo " Alkalmazas kezelese:"
 echo " start - MicroK8s + port-forward inditasa"
 echo " stop - Port-forward leallitasa"
 echo " restart - Podok + port-forward ujrainditasa"
 echo " status - Allapot ellenorzese"
 echo ""
 echo " Telepites:"
 echo " install - Teljes telepites futtatasa (setup.sh)"
 echo " uninstall - Eltavolitas (uninstall.sh)"
 echo " deploy - Csak az Ansible deploy futtatasa"
 echo " redeploy - Ujrabuild + deploy (image + K8s)"
 echo ""
 echo " Informacio:"
 echo " logs - API pod logjainak megtekintese"
 echo " pods - Podok allapota"
 echo " help - Ez a sugo"
 echo ""
 echo " GitHub:"

 echo ""
}

status() {
 section "MikroCsirip - Allapot"
 echo ""

 echo -e "${BLUE}MicroK8s allapot:${NC}"
 if microk8s status 2>/dev/null | grep -q "microk8s is running"; then
 log "MicroK8s fut"
 else
 warn "MicroK8s nem fut"
 fi
 echo ""

 echo -e "${BLUE}Kubernetes podok:${NC}"
 microk8s kubectl get pods -n $NAMESPACE 2>/dev/null || warn "Kubernetes nem elerheto"
 echo ""

 NODE_IP=$(microk8s kubectl get nodes -o jsonpath="{.items[0].status.addresses[?(@.type==\"InternalIP\")].address}" 2>/dev/null)

 echo -e "${BLUE}Ingress elerhetoseg:${NC}"
 if curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP 2>/dev/null | grep -q "200\|304"; then
 log "Frontend: http://$NODE_IP"
 else
 warn "Frontend nem elerheto: http://$NODE_IP"
 fi
 if curl -s -o /dev/null -w "%{http_code}" http://$NODE_IP/health 2>/dev/null | grep -q "200"; then
 log "API: http://$NODE_IP/api"
 else
 warn "API nem elerheto: http://$NODE_IP/api"
 fi
}

start() {
 section "MikroCsirip - Inditas"

 microk8s_start_wait

 log "Podok ellenorzese..."
 PODS_READY=$(microk8s kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep "1/1" | wc -l)
 PODS_TOTAL=$(microk8s kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | wc -l)

 if [ "$PODS_TOTAL" -eq 0 ]; then
 warn "Nincsenek podok. Futtasd: ./mikrocsirip.sh deploy"
 exit 1
 elif [ "$PODS_READY" -lt "$PODS_TOTAL" ]; then
 warn "Nem minden pod fut ($PODS_READY/$PODS_TOTAL). Varakozas..."
 microk8s kubectl wait --for=condition=ready pod --all -n $NAMESPACE --timeout=180s 2>/dev/null || true
 else
 log "Minden pod fut ($PODS_READY/$PODS_TOTAL)"
 fi

 log "Port-forward inditasa..."
 pkill -f "kubectl port-forward svc/mikrocsirip" 2>/dev/null || true
 sleep 1

 nohup microk8s kubectl port-forward svc/mikrocsirip-frontend-svc $FRONTEND_PORT:80 \
 -n $NAMESPACE > /tmp/mikrocsirip-frontend-pf.log 2>&1 &
 nohup microk8s kubectl port-forward svc/mikrocsirip-api-svc $API_PORT:80 \
 -n $NAMESPACE > /tmp/mikrocsirip-api-pf.log 2>&1 &

 sleep 3

 section "MikroCsirip elindult"
 echo ""
 echo -e " ${GREEN}Frontend : http://localhost:$FRONTEND_PORT${NC}"
 echo -e " ${GREEN}API : http://localhost:$API_PORT/api${NC}"
 echo -e " ${GREEN}Swagger : http://localhost:$API_PORT/swagger${NC}"
 echo ""
}

stop() {
 section "MikroCsirip - Leallitas"
 log "MicroK8s leallitasa..."
 microk8s stop
 log "MicroK8s leallitva"
}

restart() {
 section "MikroCsirip - Ujrainditás"
 stop
 sleep 2
 microk8s_start_wait
 log "Podok ujrainditasa..."
 microk8s kubectl rollout restart deployment/mikrocsirip-api -n $NAMESPACE 2>/dev/null || true
 microk8s kubectl rollout restart deployment/mikrocsirip-frontend -n $NAMESPACE 2>/dev/null || true
 microk8s kubectl rollout status deployment/mikrocsirip-api -n $NAMESPACE --timeout=120s 2>/dev/null || true
 microk8s kubectl rollout status deployment/mikrocsirip-frontend -n $NAMESPACE --timeout=120s 2>/dev/null || true
 start
}

install() {
 section "MikroCsirip - Telepites"
 if [ ! -f "$SCRIPT_DIR/setup.sh" ]; then
 error "setup.sh nem talalhato: $SCRIPT_DIR/setup.sh"
 fi
 chmod +x "$SCRIPT_DIR/setup.sh"
 "$SCRIPT_DIR/setup.sh"
}

uninstall() {
 section "MikroCsirip - Eltavolitas"
 if [ ! -f "$SCRIPT_DIR/uninstall.sh" ]; then
 error "uninstall.sh nem talalhato: $SCRIPT_DIR/uninstall.sh"
 fi
 chmod +x "$SCRIPT_DIR/uninstall.sh"
 "$SCRIPT_DIR/uninstall.sh"
}

deploy() {
 section "MikroCsirip - Ansible Deploy"
 microk8s_start_wait
 cd "$SCRIPT_DIR/ansible"
 sg microk8s -c "ansible-playbook playbooks/deploy-local.yml \
 -e \"project_root=$SCRIPT_DIR\" \
 -e \"api_port=$API_PORT\" \
 -e \"frontend_port=$FRONTEND_PORT\""
}

redeploy() {
 section "MikroCsirip - Ujrabuild es Deploy"
 microk8s_start_wait
 cd "$SCRIPT_DIR/ansible"
 sg microk8s -c "ansible-playbook playbooks/deploy-local.yml \
 -e \"project_root=$SCRIPT_DIR\" \
 -e \"api_port=$API_PORT\" \
 -e \"frontend_port=$FRONTEND_PORT\" \
 --tags registry,deploy"
}

logs() {
 section "MikroCsirip - API Logok"
 microk8s kubectl logs -f deployment/mikrocsirip-api -n $NAMESPACE
}

pods() {
 section "MikroCsirip - Podok"
 microk8s kubectl get pods -n $NAMESPACE -o wide
}

# ── Fő logika ────────────────────────────────────────────────

case "${1:-help}" in
 start) start ;;
 stop) stop ;;
 restart) restart ;;
 status) status ;;
 install) install ;;
 uninstall) uninstall ;;
 deploy) deploy ;;
 redeploy) redeploy ;;
 logs) logs ;;
 pods) pods ;;

 help|*) usage ;;
esac
