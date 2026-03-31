#!/bin/bash
# deploy-azure.sh – MikroCsirip teljes Azure deploy szkript (MSSQL verzió)
# Használat: chmod +x deploy-azure.sh && ./deploy-azure.sh

set -e

# ─── Konfiguráció ───────────────────────────────────────────────
RESOURCE_GROUP="mikrocsirip-rg"
LOCATION="westeurope"
SQL_SERVER="mikrocsirip-sql"
SQL_DB="mikrocsirip"
SQL_ADMIN="adminuser"
APP_SERVICE_PLAN="mikrocsirip-plan"
API_APP_NAME="mikrocsirip-api"
STATIC_APP_NAME="mikrocsirip-frontend"

# ─── Jelszó bekérése ────────────────────────────────────────────
read -s -p "SQL Server jelszó (min. 8 karakter, szám és nagybetű): " SQL_PASSWORD
echo
read -s -p "JWT Secret Key (min. 32 karakter): " JWT_KEY
echo

# ─── Resource Group ─────────────────────────────────────────────
echo "▶ Resource Group létrehozása..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# ─── Azure SQL ──────────────────────────────────────────────────
echo "▶ Azure SQL Server létrehozása..."
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

echo "▶ Adatbázis létrehozása..."
az sql db create \
 --resource-group $RESOURCE_GROUP \
 --server $SQL_SERVER \
 --name $SQL_DB \
 --edition Basic \
 --capacity 5

CONN_STRING="Server=${SQL_SERVER}.database.windows.net;Database=${SQL_DB};User Id=${SQL_ADMIN};Password=${SQL_PASSWORD};TrustServerCertificate=True;"

# ─── App Service ────────────────────────────────────────────────
echo "▶ App Service Plan létrehozása..."
az appservice plan create \
 --name $APP_SERVICE_PLAN \
 --resource-group $RESOURCE_GROUP \
 --sku B1 \
 --is-linux

echo "▶ Web App létrehozása..."
az webapp create \
 --resource-group $RESOURCE_GROUP \
 --plan $APP_SERVICE_PLAN \
 --name $API_APP_NAME \
 --runtime "DOTNETCORE:8.0"

az webapp config appsettings set \
 --resource-group $RESOURCE_GROUP \
 --name $API_APP_NAME \
 --settings \
 "ConnectionStrings__DefaultConnection=${CONN_STRING}" \
 "Jwt__Key=${JWT_KEY}" \
 "Jwt__Issuer=MikroCsirip" \
 "Jwt__Audience=MikroCsiripUsers" \
 "ASPNETCORE_ENVIRONMENT=Production"

# ─── Backend deploy ─────────────────────────────────────────────
echo "▶ Backend build és deploy..."
cd backend/MikroCsirip
dotnet publish -c Release -o ./publish --nologo -q
cd publish && zip -r ../deploy.zip . -q && cd ..
az webapp deploy \
 --resource-group $RESOURCE_GROUP \
 --name $API_APP_NAME \
 --src-path deploy.zip \
 --type zip
rm -rf publish deploy.zip
cd ../..

API_URL="https://${API_APP_NAME}.azurewebsites.net/api"
echo " Backend deploy kész: $API_URL"

# ─── Frontend build ─────────────────────────────────────────────
echo "▶ Frontend build..."
cd frontend

cat > src/environments/environment.prod.ts << EOF
export const environment = {
 production: true,
 apiUrl: '${API_URL}'
};
EOF

npm install --silent
npx ng build --configuration production --no-progress

echo "▶ Static Web App létrehozása..."
az staticwebapp create \
 --name $STATIC_APP_NAME \
 --resource-group $RESOURCE_GROUP \
 --location $LOCATION

DEPLOY_TOKEN=$(az staticwebapp secrets list \
 --name $STATIC_APP_NAME \
 --resource-group $RESOURCE_GROUP \
 --query "properties.apiKey" -o tsv)

npm install -g @azure/static-web-apps-cli --silent
swa deploy dist/mikrocsirip-frontend/browser \
 --deployment-token $DEPLOY_TOKEN \
 --env production

FRONTEND_URL="https://${STATIC_APP_NAME}.azurestaticapps.net"
cd ..

# ─── CORS frissítése ────────────────────────────────────────────
echo "▶ CORS beállítása..."
az webapp config appsettings set \
 --resource-group $RESOURCE_GROUP \
 --name $API_APP_NAME \
 --settings "AllowedOrigin=${FRONTEND_URL}"

az webapp restart --name $API_APP_NAME --resource-group $RESOURCE_GROUP

# ─── Összefoglaló ───────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo " Deploy sikeres!"
echo "════════════════════════════════════════"
echo " Frontend : $FRONTEND_URL"
echo " Backend : $API_URL"
echo " Swagger : https://${API_APP_NAME}.azurewebsites.net/swagger"
echo "════════════════════════════════════════"
