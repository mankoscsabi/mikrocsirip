# Fejlesztői dokumentáció

## Tartalomjegyzék

- [Architektúra](#architektura)
- [Backend](#backend)
- [Frontend](#frontend)
- [Adatbázis](#adatbazis)
- [Autentikáció](#autentikacio)
- [API végpontok](#api-vegpontok)
- [Kubernetes](#kubernetes)
- [Ansible](#ansible)
- [Fejlesztési munkafolyamat](#fejlesztesi-munkafolyamat)

---

## Architektúra

```
Böngészo
 |
 | HTTP
 v
Angular SPA (port 4200)
 |
 | HTTP/JSON
 v
.NET 8 Web API (port 8081)
 |
 | EF Core
 v
SQL Server (port 1433)
```

Kubernetes alatt minden komponens külön pod-ban fut, a kommunikáció ClusterIP service-eken keresztül történik. A felhasználó a `kubectl port-forward` segítségével éri el az alkalmazást.

---

## Backend

### Projekt struktúra

```
backend/MikroCsirip/
├── Controllers/
│ └── Controllers.cs AuthController, PostsController, UsersController
├── Data/
│ └── AppDbContext.cs EF Core DbContext, Hungarian_CI_AS collation
├── DTOs/
│ └── DTOs.cs Request/Response objektumok
├── Models/
│ └── Models.cs User, Post, Follow, Like entitások
├── Services/
│ ├── AuthService.cs JWT generálás, BCrypt jelszó hash
│ ├── PostService.cs CRUD, like/unlike, feed
│ └── UserService.cs Profil, követés, keresés
└── Program.cs DI konfiguráció, middleware pipeline
```

### Fontos beállítások

**Program.cs** regisztrálja a szolgáltatásokat és konfigurálja:
- SQL Server kapcsolat (EF Core + Pomelo)
- JWT autentikáció
- CORS (AllowedOrigin appsettings-ből)
- Health check endpoint (`/health`)
- Swagger (csak Development módban)
- Auto-migrate induláskor

### Új végpont hozzáadása

1. DTO létrehozása a `DTOs/DTOs.cs`-ben
2. Service interfész és implementáció a `Services/` mappában
3. Controller metódus a `Controllers/Controllers.cs`-ben
4. Service regisztrálása a `Program.cs`-ben

### Migráció

```bash
cd backend/MikroCsirip
dotnet ef migrations add MigracioNeve
dotnet ef database update
```

---

## Frontend

### Projekt struktúra

```
frontend/src/app/
├── core/
│ ├── services/
│ │ ├── auth.service.ts JWT tárolás, login/register/logout
│ │ └── api.service.ts PostService, UserService HTTP hívások
│ ├── guards/
│ │ └── auth.guard.ts Védett útvonalak
│ └── interceptors/
│ └── auth.interceptor.ts JWT csatolása minden kéréshez
├── features/
│ ├── auth/
│ │ ├── login.component.ts
│ │ └── register.component.ts
│ ├── feed/
│ │ └── feed.component.ts Főoldal, bejegyzés írás, like
│ └── profile/
│ └── profile.component.ts Felhasználói profil, követés
└── shared/
 └── models/
 └── models.ts TypeScript interfészek
```

### State management

Az alkalmazás Angular Signals-t használ state managementre. A `AuthService.currentUser` signal tárolja a bejelentkezett felhasználót.

### Új oldal hozzáadása

1. Komponens létrehozása a `features/` mappában
2. Route hozzáadása az `app.routes.ts`-ben (lazy loading)
3. Ha védett, az `authGuard` hozzáadása a route-hoz

### API URL konfiguráció

Fejlesztői mód: `src/environments/environment.ts`
Éles mód: `src/environments/environment.prod.ts`

---

## Adatbázis

### Entitások

| Tábla | Leírás |
|-------|--------|
| Users | Felhasználók (username, email, passwordHash, bio) |
| Posts | Bejegyzések (content max 280 kar, userId FK) |
| Follows | Követések (followerId, followingId kompozit PK) |
| Likes | Like-ok (userId, postId kompozit PK) |

### Collation

Az adatbázis `Hungarian_CI_AS` collation-t használ, ami biztosítja a magyar ékezetes karakterek helyes kezelését. A beállítás az `AppDbContext.OnModelCreating` metódusban történik.

### Cascade delete szabályok

- Post törlésekor a hozzá tartozó Like-ok törlődnek (Cascade)
- User törlésekor a Post-ok törlődnek (Cascade)
- Like -> User: Restrict (cascade cycle elkerülése miatt)
- Follow -> User: Restrict mindkét irányban

---

## Autentikáció

JWT (JSON Web Token) alapú autentikáció. A token 7 napig érvényes.

### Token tartalma

```json
{
 "nameid": "1",
 "unique_name": "felhasznalonev",
 "email": "email@example.com",
 "exp": 1234567890
}
```

### Védett végpontok

Az `[Authorize]` attribútummal ellátott controller metódusok Bearer tokent várnak a `Authorization` headerben.

---

## API végpontok

### Autentikáció

| Metódus | URL | Leírás |
|---------|-----|--------|
| POST | `/api/auth/register` | Regisztráció |
| POST | `/api/auth/login` | Bejelentkezés |

### Bejegyzések

| Metódus | URL | Auth | Leírás |
|---------|-----|------|--------|
| GET | `/api/posts/feed` | igen | Feed lekérése (page, pageSize) |
| POST | `/api/posts` | igen | Új bejegyzés |
| POST | `/api/posts/{id}/like` | igen | Like / unlike |
| DELETE | `/api/posts/{id}` | igen | Törlés |

### Felhasználók

| Metódus | URL | Auth | Leírás |
|---------|-----|------|--------|
| GET | `/api/users/{username}` | nem | Profil |
| GET | `/api/users/{username}/posts` | nem | Felhasználó bejegyzései |
| PUT | `/api/users/me` | igen | Profil szerkesztése |
| POST | `/api/users/{username}/follow` | igen | Követés / unfollow |
| GET | `/api/users/search?q=` | nem | Keresés |

### Egyéb

| Metódus | URL | Leírás |
|---------|-----|--------|
| GET | `/health` | Health check (Kubernetes probe) |
| GET | `/swagger` | API dokumentáció (csak dev) |

---

## Kubernetes

### Namespace

Minden erőforrás a `mikrocsirip` namespace-ben fut.

### Podok

| Deployment | Image | Port |
|-----------|-------|------|
| mikrocsirip-api | lokális registry | 8080 |
| mikrocsirip-frontend | lokális registry | 80 |
| mikrocsirip-mssql | mcr.microsoft.com/mssql/server:2022 | 1433 |

### Secret

A `mikrocsirip-secrets` Secret tartalmazza:
- `db-connection-string`: SQL Server kapcsolati string
- `jwt-key`: JWT aláíró kulcs

### ConfigMap

A `mikrocsirip-config` ConfigMap tartalmazza:
- `frontend-url`: Frontend URL (CORS beállításhoz)

### Hasznos kubectl parancsok

```bash
# Podok állapota
kubectl get pods -n mikrocsirip

# API logok
kubectl logs -f deployment/mikrocsirip-api -n mikrocsirip

# SQL Server shell
kubectl exec -it deployment/mikrocsirip-mssql -n mikrocsirip -- \
 /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "JELSZO" -C

# Skálázás
kubectl scale deployment mikrocsirip-api --replicas=2 -n mikrocsirip

# Port-forward manuálisan
kubectl port-forward svc/mikrocsirip-api-svc 8081:80 -n mikrocsirip
kubectl port-forward svc/mikrocsirip-frontend-svc 4200:80 -n mikrocsirip
```

---

## Ansible

### Role-ok

| Role | Feladat |
|------|---------|
| local-registry | Docker registry indítás, daemon.json, k3s konfig, image build és push |
| k8s-namespace | Namespace, ConfigMap létrehozás |
| local-sql | SQL Server pod deploy, adatbázis létrehozás, EF migráció, Secret |
| k8s-deploy | API és Frontend deployment, rollout várakozás |

### Részleges futtatás tag-ekkel

```bash
cd ansible

# Csak image build és deploy
ansible-playbook playbooks/deploy-local.yml \
 -e "project_root=$HOME/mikrocsirip" \
 -e "api_port=8081" \
 -e "frontend_port=4200" \
 --tags registry,deploy

# Csak K8s deploy (image már megvan)
ansible-playbook playbooks/deploy-local.yml \
 -e "project_root=$HOME/mikrocsirip" \
 -e "api_port=8081" \
 -e "frontend_port=4200" \
 --tags deploy
```

---

## Fejlesztési munkafolyamat

### Backend módosítás deploy-olása

```bash
# 1. Kód módosítása
# 2. Image újraépítése
DOCKER_IP=$(ip addr show docker0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
docker build -t $DOCKER_IP:5000/mikrocsirip-api:latest \
 -f backend/MikroCsirip/Dockerfile backend/MikroCsirip/
docker push $DOCKER_IP:5000/mikrocsirip-api:latest

# 3. Pod újraindítása
kubectl rollout restart deployment/mikrocsirip-api -n mikrocsirip
kubectl rollout status deployment/mikrocsirip-api -n mikrocsirip
```

### Frontend módosítás deploy-olása

```bash
DOCKER_IP=$(ip addr show docker0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
docker build -t $DOCKER_IP:5000/mikrocsirip-frontend:latest \
 -f frontend/Dockerfile frontend/
docker push $DOCKER_IP:5000/mikrocsirip-frontend:latest

kubectl rollout restart deployment/mikrocsirip-frontend -n mikrocsirip
```

### Adatbázis migráció hozzáadása

```bash
cd backend/MikroCsirip
dotnet ef migrations add MigracioNeve
dotnet ef database update

# Kubernetes-ben a migráció automatikusan lefut induláskor (Program.cs auto-migrate)
kubectl rollout restart deployment/mikrocsirip-api -n mikrocsirip
```
