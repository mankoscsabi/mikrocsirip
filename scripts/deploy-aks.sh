#!/bin/bash
# deploy-aks.sh – MikroCsirip Azure Kubernetes Service deploy
# Használat: chmod +x deploy-aks.sh && ./deploy-aks.sh

set -e

# ─── Konfiguráció ───────────────────────────────────────────────
RESOURCE_GROUP="mikrocsirip-rg"
LOCATION="westeurope"
AKS_CLUSTER="mikrocsirip-aks"
ACR_NAME="mikrocsiripacr" # Egyedi névnek kell lennie!
SQL_SERVER="mikrocsirip-sql"
SQL_DB="mikrocsirip"
SQL_ADMIN="adminuser"
NAMESPACE="mikrocsirip"
IMAGE_TAG=${1:-"latest"} # Opcionális: ./deploy-aks.sh v1.0.0

# ─── Adatok bekérése ────────────────────────────────────────────
read -s -p "SQL Server jelszó: " SQL_PASSWORD; echo
read -s -p "JWT Secret Key (min 32 kar): " JWT_KEY; echo

# ─── Resource Group ─────────────────────────────────────────────
echo "▶ Resource Group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# ─── Azure Container Registry ───────────────────────────────────
echo "▶ Container Registry létrehozása..."
az acr create \
 --resource-group $RESOURCE_GROUP \
 --name $ACR_NAME \
 --sku Basic \
 --admin-enabled true

ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
echo " ACR: $ACR_LOGIN_SERVER"

# ─── Docker image build & push ──────────────────────────────────
echo "▶ Backend image build..."
az acr build \
 --registry $ACR_NAME \
 --image mikrocsirip-api:$IMAGE_TAG \
 --file backend/MikroCsirip/Dockerfile \
 backend/MikroCsirip/

echo "▶ Frontend image build..."
az acr build \
 --registry $ACR_NAME \
 --image mikrocsirip-frontend:$IMAGE_TAG \
 --file frontend/Dockerfile \
 frontend/

# ─── Azure SQL ──────────────────────────────────────────────────
echo "▶ Azure SQL Server..."
az sql server create \
 --resource-group $RESOURCE_GROUP \
 --name $SQL_SERVER \
 --location $LOCATION \
 --admin-user $SQL_ADMIN \
 --admin-password "$SQL_PASSWORD"

az sql server firewall-rule create \
 --resource-group $RESOURCE_GROUP \
 --server $SQL_SERVER \
 --name AllowAzureServices \
 --start-ip-address 0.0.0.0 \
 --end-ip-address 0.0.0.0

az sql db create \
 --resource-group $RESOURCE_GROUP \
 --server $SQL_SERVER \
 --name $SQL_DB \
 --edition Basic \
 --capacity 5

CONN_STRING="Server=${SQL_SERVER}.database.windows.net;Database=${SQL_DB};User Id=${SQL_ADMIN};Password=${SQL_PASSWORD};TrustServerCertificate=True;"

# ─── AKS Cluster ────────────────────────────────────────────────
echo "▶ AKS cluster létrehozása (5-10 perc)..."
az aks create \
 --resource-group $RESOURCE_GROUP \
 --name $AKS_CLUSTER \
 --node-count 2 \
 --node-vm-size Standard_B2s \
 --enable-managed-identity \
 --attach-acr $ACR_NAME \
 --generate-ssh-keys \
 --location $LOCATION

# Kubectl konfig letöltése
az aks get-credentials \
 --resource-group $RESOURCE_GROUP \
 --name $AKS_CLUSTER

# ─── Namespace ──────────────────────────────────────────────────
echo "▶ Kubernetes namespace..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# ─── Secrets ────────────────────────────────────────────────────
echo "▶ Kubernetes secrets..."
kubectl create secret generic mikrocsirip-secrets \
 --namespace $NAMESPACE \
 --from-literal=db-connection-string="$CONN_STRING" \
 --from-literal=jwt-key="$JWT_KEY" \
 --dry-run=client -o yaml | kubectl apply -f -

# ─── NGINX Ingress Controller ────────────────────────────────────
echo "▶ NGINX Ingress telepítése..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

echo " Várakozás az Ingress IP-re..."
sleep 60
INGRESS_IP=$(kubectl get svc ingress-nginx-controller \
 -n ingress-nginx \
 -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo " Ingress IP: $INGRESS_IP"

# ─── Kubernetes manifests deploy ────────────────────────────────
echo "▶ K8s manifests alkalmazása..."

# Image registry beállítása
sed -i "s|REGISTRY|${ACR_LOGIN_SERVER}|g" k8s/base/api-deployment.yaml
sed -i "s|REGISTRY|${ACR_LOGIN_SERVER}|g" k8s/base/frontend-deployment.yaml
sed -i "s|latest|${IMAGE_TAG}|g" k8s/base/api-deployment.yaml
sed -i "s|latest|${IMAGE_TAG}|g" k8s/base/frontend-deployment.yaml
sed -i "s|mikrocsirip.example.com|${INGRESS_IP}.nip.io|g" k8s/base/ingress.yaml
sed -i "s|mikrocsirip.example.com|${INGRESS_IP}.nip.io|g" k8s/base/secrets.yaml

kubectl apply -k k8s/base/ --namespace $NAMESPACE

# ─── Összefoglaló ───────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " AKS Deploy sikeres!"
echo "════════════════════════════════════════"
echo " App URL : http://${INGRESS_IP}.nip.io"
echo " API URL : http://${INGRESS_IP}.nip.io/api"
echo " Cluster : $AKS_CLUSTER"
echo " Registry : $ACR_LOGIN_SERVER"
echo ""
echo " Podok állapota:"
kubectl get pods -n $NAMESPACE
echo "════════════════════════════════════════"
