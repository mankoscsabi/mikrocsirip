# Azure Kubernetes Service (AKS) Deploy

## Architektúra

```
Internet
 │
 ▼
NGINX Ingress (LoadBalancer IP)
 ├── /api/* → mikrocsirip-api (2-3 pod)
 └── /* → mikrocsirip-frontend (2 pod)
 │
 ▼
 Azure SQL Database
```

## Előfeltételek

```bash
# Azure CLI
az --version

# kubectl
kubectl version --client

# Docker (lokális build-hez, opcionális)
docker --version
```

---

## 1. Gyors deploy (szkripttel)

```bash
chmod +x scripts/deploy-aks.sh
./scripts/deploy-aks.sh
```

Opcionálisan image tag-gel:
```bash
./scripts/deploy-aks.sh v1.0.0
```

---

## 2. Manuális deploy lépések

### Azure Container Registry

```bash
# ACR létrehozása
az acr create \
 --resource-group mikrocsirip-rg \
 --name mikrocsiripacr \
 --sku Basic

# Backend image build és push
az acr build \
 --registry mikrocsiripacr \
 --image mikrocsirip-api:latest \
 --file backend/MikroCsirip/Dockerfile \
 backend/MikroCsirip/

# Frontend image build és push
az acr build \
 --registry mikrocsiripacr \
 --image mikrocsirip-frontend:latest \
 --file frontend/Dockerfile \
 frontend/
```

### AKS Cluster

```bash
az aks create \
 --resource-group mikrocsirip-rg \
 --name mikrocsirip-aks \
 --node-count 2 \
 --node-vm-size Standard_B2s \
 --enable-managed-identity \
 --attach-acr mikrocsiripacr \
 --generate-ssh-keys

# Kubectl konfig
az aks get-credentials \
 --resource-group mikrocsirip-rg \
 --name mikrocsirip-aks
```

### Secrets beállítása

```bash
kubectl create namespace mikrocsirip

kubectl create secret generic mikrocsirip-secrets \
 --namespace mikrocsirip \
 --from-literal=db-connection-string="Server=...;Database=mikrocsirip;..." \
 --from-literal=jwt-key="SuperSecretKey32CharsMin!!"
```

### Manifests deploy

```bash
# Image registry beállítása
ACR_SERVER=$(az acr show --name mikrocsiripacr --query loginServer -o tsv)
sed -i "s|REGISTRY|${ACR_SERVER}|g" k8s/base/api-deployment.yaml
sed -i "s|REGISTRY|${ACR_SERVER}|g" k8s/base/frontend-deployment.yaml

# Deploy
kubectl apply -k k8s/base/ --namespace mikrocsirip
```

---

## 3. Hasznos kubectl parancsok

```bash
# Podok állapota
kubectl get pods -n mikrocsirip

# Logok
kubectl logs -f deployment/mikrocsirip-api -n mikrocsirip
kubectl logs -f deployment/mikrocsirip-frontend -n mikrocsirip

# Skálázás
kubectl scale deployment mikrocsirip-api --replicas=3 -n mikrocsirip

# Új image deploy (rolling update)
kubectl set image deployment/mikrocsirip-api \
 api=mikrocsiripacr.azurecr.io/mikrocsirip-api:v1.1.0 \
 -n mikrocsirip

# Rollback
kubectl rollout undo deployment/mikrocsirip-api -n mikrocsirip

# Ingress IP lekérése
kubectl get ingress -n mikrocsirip

# Service-ek
kubectl get svc -n mikrocsirip
```

---

## 4. CI/CD GitHub Actions-szel

A `.github/workflows/deploy-aks.yml` automatikusan:
1. Build-eli a Docker image-eket
2. Push-olja az ACR-be
2. Deploy-olja az AKS-re minden `main` push után

**Szükséges GitHub Secrets:**
```
AZURE_CREDENTIALS – az ad sp create-for-rbac kimenet JSON-ban
```

Service Principal létrehozása:
```bash
az ad sp create-for-rbac \
 --name mikrocsirip-sp \
 --role contributor \
 --scopes /subscriptions/YOUR_SUB_ID/resourceGroups/mikrocsirip-rg \
 --sdk-auth
```

---

## Becsült havi költség (AKS)

| Erőforrás | Méret | Ár |
|-----------|-------|-----|
| AKS (2x Standard_B2s) | 2 node | ~$60/hó |
| Azure SQL | Basic | ~$5/hó |
| Container Registry | Basic | ~$5/hó |
| Load Balancer | Standard | ~$18/hó |
| **Összesen** | | **~$88/hó** |

> Olcsóbb alternatíva: 1 node + Standard_B1ms → ~$40/hó
