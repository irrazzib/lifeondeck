# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Layout

Monorepo with two projects:

```
client/   # Flutter app (mobile + web)  — see client/CLAUDE.md
api/      # ASP.NET Core 10 REST API     — see api/CLAUDE.md
```

For per-project commands and architecture, read the `CLAUDE.md` inside each folder. This file documents only the cross-cutting contract between them.

## Client ↔ API sync contract

The Flutter client (`client/`) syncs through the API (`api/`) over these endpoints:

| Method | Route | Auth | Description |
|--------|-------|------|-------------|
| POST | `/api/v1/auth/firebase` | No | Exchange Firebase ID token → app JWT |
| GET  | `/api/v1/sync?since=<ISO8601>` | JWT | Pull changes since timestamp |
| POST | `/api/v1/sync` | JWT | Push batch of changes |

- **Auth:** client signs in with Firebase → sends Firebase ID token to `/auth/firebase` → receives app JWT → stores it in `FlutterSecureStorage` → sends it as bearer on every request.
- **Sync:** last-write-wins by client `UpdatedAt`. Soft deletes via `DeletedAt`. Payloads (`GameRecordEntity`, `SideboardDeckEntity`, `AppSettingsEntity`) travel as raw JSON blobs — the server is schema-agnostic for those, so the client owns the blob shape.

Changing the wire shape requires touching both sides: serialisation in `client/lib/services/sync_service.dart` and the upsert/pull paths in `api/LifeOnDeck.Api/Controllers/SyncController.cs`.
