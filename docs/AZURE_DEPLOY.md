# Azure Deployment Guide

Ez az útmutató lépésről lépésre végigvezet a MikroCsirip Azure-ra való deployolásán.

## Szükséges Azure erőforrások

| Erőforrás | Típus | Megjegyzés |
|-----------|-------|------------|
| Resource Group | `mikrocsirip-rg` | Minden erőforrás konténere |
| App Service Plan | B1 (Basic) | .NET Core backend futtatás |
| App Service | `mikrocsirip-api` | Web API |
| Azure SQL Database | Basic / S0 | Adatbázis (MSSQL) |
| Static Web App | `mikrocsirip-frontend` | Angular frontend |

---

## 1. Előfeltételek

```bash
# Azure CLI telepítése
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli

# Bejelentkezés
az login

# Előfizetés beállítása (ha több van)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

---

## 2. Resource Group létrehozása

```bash
az group create \
 --name mikrocsirip-rg \
 --location westeurope
```

---

## 3. Azure SQL Server + Database

```bash
# SQL Server létrehozása
az sql server create \
 --resource-group mikrocsirip-rg \
 --name mikrocsirip-sql \
 --location westeurope \
 --admin-user adminuser \
 --admin-password "YourStrongPassword123!"

# Tűzfal: Azure szolgáltatások engedélyezése
az sql server firewall-rule create \
 --resource-group mikrocsirip-rg \
 --server mikrocsirip-sql \
 --name AllowAzureServices \
 --start-ip-address 0.0.0.0 \
 --end-ip-address 0.0.0.0

# Adatbázis létrehozása (Basic tier)
az sql db create \
 --resource-group mikrocsirip-rg \
 --server mikrocsirip-sql \
 --name mikrocsirip \
 --edition Basic \
 --capacity 5
```

> **Connection string formátum:**
> `Server=mikrocsirip-sql.database.windows.net;Database=mikrocsirip;User Id=adminuser;Password=YourStrongPassword123!;TrustServerCertificate=True;`

---

## 4. App Service (Backend)

```bash
# App Service Plan
az appservice plan create \
 --name mikrocsirip-plan \
 --resource-group mikrocsirip-rg \
 --sku B1 \
 --is-linux

# Web App
az webapp create \
 --resource-group mikrocsirip-rg \
 --plan mikrocsirip-plan \
 --name mikrocsirip-api \
 --runtime "DOTNETCORE:8.0"

# Alkalmazás beállítások
az webapp config appsettings set \
 --resource-group mikrocsirip-rg \
 --name mikrocsirip-api \
 --settings \
 "ConnectionStrings__DefaultConnection=Server=mikrocsirip-sql.database.windows.net;Database=mikrocsirip;User Id=adminuser;Password=YourStrongPassword123!;TrustServerCertificate=True;" \
 "Jwt__Key=YourSuperSecretKeyHereMustBe32CharsMin!!" \
 "Jwt__Issuer=MikroCsirip" \
 "Jwt__Audience=MikroCsiripUsers" \
 "AllowedOrigin=https://mikrocsirip-frontend.azurestaticapps.net" \
 "ASPNETCORE_ENVIRONMENT=Production"
```

### Backend deploy

```bash
cd backend/MikroCsirip

dotnet publish -c Release -o ./publish

cd publish
zip -r ../deploy.zip .
cd ..

az webapp deploy \
 --resource-group mikrocsirip-rg \
 --name mikrocsirip-api \
 --src-path deploy.zip \
 --type zip
```

---

## 5. Static Web App (Frontend)

```bash
cd frontend
npm install
ng build --configuration production

az staticwebapp create \
 --name mikrocsirip-frontend \
 --resource-group mikrocsirip-rg \
 --location westeurope

# Deploy token lekérése
DEPLOY_TOKEN=$(az staticwebapp secrets list \
 --name mikrocsirip-frontend \
 --resource-group mikrocsirip-rg \
 --query "properties.apiKey" -o tsv)

npm install -g @azure/static-web-apps-cli
swa deploy dist/mikrocsirip-frontend/browser \
 --deployment-token $DEPLOY_TOKEN \
 --env production
```

---

## 6. CORS frissítése

Miután megvan a frontend URL, frissítsd a backend beállítást:

```bash
az webapp config appsettings set \
 --resource-group mikrocsirip-rg \
 --name mikrocsirip-api \
 --settings "AllowedOrigin=https://mikrocsirip-frontend.azurestaticapps.net"
```

---

## 7. Ellenőrzés

```bash
# Swagger UI
open https://mikrocsirip-api.azurewebsites.net/swagger

# Health check
curl https://mikrocsirip-api.azurewebsites.net/api/users/search?q=test
```

---

## Hasznos parancsok

```bash
# Logok megtekintése
az webapp log tail --name mikrocsirip-api --resource-group mikrocsirip-rg

# App Service újraindítása
az webapp restart --name mikrocsirip-api --resource-group mikrocsirip-rg

# SQL kapcsolat tesztelése (helyi sqlcmd-del)
sqlcmd -S mikrocsirip-sql.database.windows.net -d mikrocsirip -U adminuser -P "YourPassword"

# Erőforrások törlése (takarítás)
az group delete --name mikrocsirip-rg --yes
```

---

## Becsült havi költség

| Erőforrás | Tier | Becsült ár |
|-----------|------|-----------|
| App Service | B1 | ~$13/hó |
| Azure SQL Database | Basic | ~$5/hó |
| Static Web App | Free | $0 |
| **Összesen** | | **~$18/hó** |
