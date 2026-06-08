# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in the API project. For the Flutter client, see `../client/CLAUDE.md`. For the cross-cutting sync contract, see `../CLAUDE.md`.

## Commands

```bash
# Run from api/
dotnet build
dotnet run --project LifeOnDeck.Api
dotnet watch --project LifeOnDeck.Api      # hot reload

# EF Core migrations (run from api/LifeOnDeck.Api/)
dotnet ef migrations add <Name>
dotnet ef database update
```

Solution file: `LifeOnDeck.slnx` (`.slnx` format, requires VS 2022+).

## Architecture

ASP.NET Core 10, EF Core + Npgsql (PostgreSQL), JWT bearer auth, .NET 10.

**Endpoints:**

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/api/v1/auth/firebase` | No | Exchange Firebase ID token → app JWT |
| GET  | `/api/v1/sync?since=<ISO8601>` | JWT | Pull changes since timestamp |
| POST | `/api/v1/sync` | JWT | Push batch of changes |

**Sync protocol:** last-write-wins by client `UpdatedAt`. Soft deletes use `DeletedAt`; EF global query filters exclude soft-deleted rows by default — use `.IgnoreQueryFilters()` when the Pull/Upsert paths need them.

**Data model:** `GameRecordEntity`, `SideboardDeckEntity`, `AppSettingsEntity` store their payload as a raw JSON blob in a `Data string` column. The server is schema-agnostic for those blobs.

**Required configuration before running:**

| Key | Where | Notes |
|-----|-------|-------|
| `ConnectionStrings:Default` | `appsettings.Development.json` | PostgreSQL connection string |
| `Jwt:SecretKey` | env var or user secrets | Replace placeholder; min 32 chars |
| `Firebase:ProjectId` | `appsettings.json` | Firebase project ID |

CORS is fully open (`AllowAnyOrigin`) — restrict before deploying to production.
