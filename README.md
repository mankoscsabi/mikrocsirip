# MikroCsirip

Egy modern microblog platform Angular, .NET Core 8 és Microsoft SQL Server alapokon, Kubernetes alatt futtatható.

## Technológiai stack

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
- Felhasználók követése / unfollow
- Feed (saját és követett felhasználók bejegyzései)
- Felhasználói profiloldalak
- Keresés felhasználók között
- Swagger UI fejlesztői módban

## Projekt struktúra

```
mikrocsirip/
├── backend/
│ └── MikroCsirip/ .NET 8 Web API
├── frontend/ Angular 17 alkalmazás
├── ansible/ Ansible playbook-ok és role-ok
│ ├── playbooks/
│ ├── roles/
│ └── group_vars/
├── k8s/ Kubernetes manifests
├── docs/ Dokumentáció
├── scripts/ Azure deploy szkriptek
├── mikrocsirip.sh Fő kezelő szkript
├── setup.sh Telepíto szkript
└── uninstall.sh Eltávolíto szkript
```

## Gyors indítás - Ubuntu VM

### Elofeltetel

Ubuntu 22.04 vagy 24.04 LTS, legalább 4 GB RAM, 20 GB szabad hely.

### Telepítés

```bash
git clone https://github.com/FELHASZNALONEV/mikrocsirip.git
cd mikrocsirip
chmod +x mikrocsirip.sh
./mikrocsirip.sh install
```

A telepíto bekéri a konfigurációs adatokat (vagy ENTER-rel elfogadja az alapértelmezetteket),
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
| `./mikrocsirip.sh git` | Commit és push GitHub-ra (git.sh) |

### GitHub kezelés (git.sh)

```bash
./git.sh init # Git inicializálás és repo beállítás
./git.sh push # Commit és push
./git.sh pull # Frissítés GitHub-ról
./git.sh status # Git állapot
./git.sh log # Commit történet
```

### Az alkalmazás elérése

```bash
./mikrocsirip.sh start
```

Böngészőben: `http://localhost:4200`

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

```bash
chmod +x scripts/deploy-aks.sh
./scripts/deploy-aks.sh
```

## API dokumentáció

Fejlesztői módban elérhető: `http://localhost:8081/swagger`

## Konfiguráció

A backend konfigurációja az `appsettings.json` fájlban történik.
Sablon: `backend/MikroCsirip/appsettings.Example.json`

Kubernetes környezetben a beállítások Secret és ConfigMap objektumokon keresztül
kerülnek a podokba, a forráskódba nem kerül érzékeny adat.

## Licenc

MIT
