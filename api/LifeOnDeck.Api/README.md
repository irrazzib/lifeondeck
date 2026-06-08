# LifeOnDeck API

ASP.NET Core 10 REST API for LifeOnDeck (Flutter client). PostgreSQL + EF Core + JWT bearer auth.

## Prerequisites

- .NET 10 SDK
- PostgreSQL 14+
- Firebase project (for ID token verification)

## Configuration

Settings are read from `appsettings.json`, `appsettings.{Environment}.json`, environment variables, and user secrets (last wins). Environment variables use the standard ASP.NET Core double-underscore convention: `Section__Key`.

### Required at runtime

| Key | Env var | Notes |
|---|---|---|
| `ConnectionStrings:Default` | `ConnectionStrings__Default` | PostgreSQL connection string. |
| `Jwt:SecretKey` | `JWT__SECRETKEY` | **Min 32 characters.** App fails fast at startup otherwise. Never commit to source. |
| `Firebase:ProjectId` | `Firebase__ProjectId` | Firebase project ID (already in `appsettings.json`). |

### Optional

| Key | Default | Notes |
|---|---|---|
| `Jwt:Issuer` | `lifeondeck-api` | |
| `Jwt:Audience` | `lifeondeck-app` | |
| `Jwt:ExpiryDays` | `7` | JWT lifetime. |

### Local development

`appsettings.Development.json` provides a dev-only `Jwt:SecretKey` placeholder so the API boots without extra setup. Do NOT reuse that value in production — set `JWT__SECRETKEY` via env var instead.

Generate a strong secret:

```bash
openssl rand -base64 48
```

Then export before running:

```bash
export JWT__SECRETKEY="<paste-generated-secret>"
export ConnectionStrings__Default="Host=...;Database=...;Username=...;Password=..."
dotnet run --project LifeOnDeck.Api
```

## Commands

```bash
dotnet build
dotnet run --project LifeOnDeck.Api
dotnet watch --project LifeOnDeck.Api      # hot reload

# EF Core migrations (run from LifeOnDeck.Api/)
dotnet ef migrations add <Name>
dotnet ef database update
```

Solution file: `LifeOnDeck.slnx`.

## Endpoints

| Method | Route | Auth | Description |
|---|---|---|---|
| POST | `/api/v1/auth/firebase` | No | Exchange Firebase ID token for app JWT. |
| GET  | `/api/v1/sync?since=<ISO8601>` | JWT | Pull changes since timestamp. |
| POST | `/api/v1/sync` | JWT | Push batch of changes. |
