# MikroCsirip

Egy modern microblog platform Angular, .NET Core 8 és Microsoft SQL Server alapokon, Kubernetes alatt futtatható.

## Tech stack

| Reteg | Technologia |
|-------|-------------|
| Frontend | Angular 17, TypeScript, SCSS |
| Backend | .NET 8, ASP.NET Core Web API |
| Adatbazis | Microsoft SQL Server 2022 |
| ORM | Entity Framework Core 8 |
| Auth | JWT Bearer token |
| Konténerizáció | Docker |
| Orchestráció | Kubernetes (MicroK8s / AKS) |
| Automatizáció | Ansible |

## Funkciók

- Regisztráció és bejelentkezés JWT alapú autentikációval
- Bejegyzések írása (max 280 karakter)
- Like / unlike bejegyzéseken
- Felhasználók követés
- Feed (saját és követett felhasználók bejegyzései)
- Felhasználói profiloldalak
- Keresés felhasználók között
- Swagger UI fejlesztői módban


### Telepítés

```bash
git clone https://github.com/mankoscsabi/mikrocsirip.git
cd mikrocsirip
chmod +x mikrocsirip.sh
./mikrocsirip.sh install
```

A telepíto bekéri a konfigurációs adatokat,
majd automatikusan elvégzi az összes telepítési lépést.

### Kezelés

Minden muvelet egyetlen szkripten keresztül érhető el:

```bash
./mikrocsirip.sh help
```

| Parancs | Leírás |
|---------|--------|
| `./mikrocsirip.sh start` | MicroK8s + port-forward indítása |
| `./mikrocsirip.sh stop` | Port-forward leállítása |
| `./mikrocsirip.sh restart` | Podok + port-forward újraindítása |
| `./mikrocsirip.sh status` | Állapot ellenőrzése |
| `./mikrocsirip.sh install` | Teljes telepítés futtatása |
| `./mikrocsirip.sh uninstall` | Eltávolítás |
| `./mikrocsirip.sh deploy` | Ansible deploy futtatása |
| `./mikrocsirip.sh redeploy` | Újrabuild + deploy |
| `./mikrocsirip.sh logs` | API pod logjainak megtekintése |
| `./mikrocsirip.sh pods` | Podok listája |



### Az alkalmazás elérése

```bash
./mikrocsirip.sh start
```

Böngészőben: `http://<IP>:4200`

### Eltávolítás

```bash
./mikrocsirip.sh uninstall
```

## Helyi fejlesztés (Windows / macOS)

Részletes útmutató: [docs/LOCAL_DEV.md](docs/LOCAL_DEV.md)

```bash
# Backend
cd backend/MikroCsirip
dotnet restore
dotnet ef database update
dotnet run

# Frontend (új terminálban)
cd frontend
npm install
ng serve
```

## Azure AKS deploy

Részletes útmutató: [docs/AKS_DEPLOY.md](docs/AKS_DEPLOY.md)



## Konfiguráció

A backend konfigurációja az `appsettings.json` fájlban történik.
Sablon: `backend/MikroCsirip/appsettings.Example.json`
