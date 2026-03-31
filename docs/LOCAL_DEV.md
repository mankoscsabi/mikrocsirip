# Helyi fejlesztési útmutató

## Előfeltételek telepítése

### Windows
```powershell
# .NET 8 SDK
winget install Microsoft.DotNet.SDK.8

# Node.js
winget install OpenJS.NodeLTS

# SQL Server
winget install Oracle.SQL Server

# Angular CLI
npm install -g @angular/cli

# EF Core Tools
dotnet tool install --global dotnet-ef
```

### macOS
```bash
brew install dotnet node mssql
npm install -g @angular/cli
dotnet tool install --global dotnet-ef
```

### Linux (Ubuntu/Debian)
```bash
# .NET 8
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y dotnet-sdk-8.0

# Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# SQL Server
sudo apt-get install -y mssql-server

# Angular CLI + EF Core
npm install -g @angular/cli
dotnet tool install --global dotnet-ef
```

---

## SQL Server beállítása

```sql
-- SQL Server shell-ben:
CREATE DATABASE mikrocsirip CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'mikrocsirip_user'@'localhost' IDENTIFIED BY 'devpassword123';
GRANT ALL PRIVILEGES ON mikrocsirip.* TO 'mikrocsirip_user'@'localhost';
FLUSH PRIVILEGES;
```

---

## Backend konfiguráció

```bash
cd backend/MikroCsirip
cp appsettings.Example.json appsettings.Development.json
```

Szerkeszd az `appsettings.Development.json`-t:
```json
{
 "ConnectionStrings": {
 "DefaultConnection": "Server=localhost;Database=mikrocsirip;Trusted_Connection=True;TrustServerCertificate=True;"
 },
 "Jwt": {
 "Key": "DevSecretKeyAtLeast32CharsLongHere!!",
 "Issuer": "MikroCsirip",
 "Audience": "MikroCsiripUsers"
 },
 "AllowedOrigin": "http://localhost:4200"
}
```

```bash
# Migráció futtatása
dotnet ef database update

# Indítás
dotnet run
# API: https://localhost:7001
# Swagger: https://localhost:7001/swagger
```

---

## Frontend konfiguráció

```bash
cd frontend
npm install
ng serve
# App: http://localhost:4200
```

---

## Fejlesztési tippek

### Új migráció hozzáadása
```bash
cd backend/MikroCsirip
dotnet ef migrations add LeíróNév
dotnet ef database update
```

### Migráció visszavonása
```bash
dotnet ef database update PreviousMigrationName
dotnet ef migrations remove
```

### Angular komponens generálása
```bash
cd frontend
ng generate component features/valami/valami
```

### API tesztelése Swagger-rel
- Nyisd meg: `https://localhost:7001/swagger`
- Regisztrálj: `POST /api/auth/register`
- Jelentkezz be: `POST /api/auth/login` → másold a tokent
- Kattints az `Authorize` gombra → `Bearer <token>`
- Tesztelj bármely végpontot

---

## Hasznos parancsok

```bash
# Backend logok fejlesztői módban
cd backend/MikroCsirip && dotnet run --verbosity detailed

# Frontend lint
cd frontend && ng lint

# Függőségek frissítése
cd backend/MikroCsirip && dotnet outdated
cd frontend && npx npm-check-updates -u && npm install
```
