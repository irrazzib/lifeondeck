using System.Security.Claims;
using LifeOnDeck.Api.Data;
using LifeOnDeck.Api.Data.Entities;
using LifeOnDeck.Api.Models.Requests;
using LifeOnDeck.Api.Models.Responses;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace LifeOnDeck.Api.Controllers;

[ApiController]
[Route("api/v1/sync")]
[Authorize]
[EnableRateLimiting("sync-policy")]
public class SyncController(AppDbContext db, ILogger<SyncController> logger) : ControllerBase
{
    private readonly AppDbContext _db = db;
    private readonly ILogger<SyncController> _logger = logger;

    /// <summary>
    /// Returns all data for the authenticated user updated after the given timestamp.
    /// Soft-deleted records are included with deleted: true when their DeletedAt > since.
    /// </summary>
    [HttpGet]
    [ProducesResponseType<SyncPullResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Pull([FromQuery] DateTime? since)
    {
        var userId = GetUserId();
        var sinceUtc = since?.ToUniversalTime() ?? DateTime.MinValue;

        _logger.LogInformation("Sync pull for user {UserId} since {Since}", userId, sinceUtc);

        // Game records: active ones updated after since
        var activeGameRecords = await _db.GameRecords
            .Where(g => g.UserId == userId && g.ServerUpdatedAt > sinceUtc)
            .Select(g => new SyncItemDto
            {
                Id = g.Id,
                Data = g.Data,
                UpdatedAt = g.UpdatedAt,
                Deleted = false,
            })
            .ToListAsync();

        // Game records: soft-deleted ones with DeletedAt > since
        var deletedGameRecords = await _db.GameRecords
            .IgnoreQueryFilters()
            .Where(g => g.UserId == userId && g.DeletedAt != null && g.ServerUpdatedAt > sinceUtc)
            .Select(g => new SyncItemDto
            {
                Id = g.Id,
                Data = g.Data,
                UpdatedAt = g.UpdatedAt,
                Deleted = true,
            })
            .ToListAsync();

        // Sideboard decks: active
        var activeSideboardDecks = await _db.SideboardDecks
            .Where(s => s.UserId == userId && s.ServerUpdatedAt > sinceUtc)
            .Select(s => new SyncItemDto
            {
                Id = s.Id,
                Data = s.Data,
                UpdatedAt = s.UpdatedAt,
                Deleted = false,
            })
            .ToListAsync();

        // Sideboard decks: soft-deleted
        var deletedSideboardDecks = await _db.SideboardDecks
            .IgnoreQueryFilters()
            .Where(s => s.UserId == userId && s.DeletedAt != null && s.ServerUpdatedAt > sinceUtc)
            .Select(s => new SyncItemDto
            {
                Id = s.Id,
                Data = s.Data,
                UpdatedAt = s.UpdatedAt,
                Deleted = true,
            })
            .ToListAsync();

        // App settings
        var appSettings = await _db.AppSettings
            .Where(a => a.UserId == userId && a.ServerUpdatedAt > sinceUtc)
            .Select(a => new SyncItemDto
            {
                Id = a.UserId.ToString(),
                Data = a.Data,
                UpdatedAt = a.UpdatedAt,
                Deleted = false,
            })
            .FirstOrDefaultAsync();

        return Ok(new SyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            GameRecords = [.. activeGameRecords, .. deletedGameRecords],
            SideboardDecks = [.. activeSideboardDecks, .. deletedSideboardDecks],
            AppSettings = appSettings,
        });
    }

    /// <summary>
    /// Pushes client changes to the server. Last-write-wins with client timestamp.
    /// </summary>
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> Push([FromBody] SyncPushRequest request)
    {
        var userId = GetUserId();
        _logger.LogInformation(
            "Sync push for user {UserId}: {GrCount} game records, {SdCount} sideboard decks",
            userId, request.GameRecords.Count, request.SideboardDecks.Count);

        await UpsertGameRecordsAsync(userId, request.GameRecords);
        await UpsertSideboardDecksAsync(userId, request.SideboardDecks);

        if (request.AppSettings is not null)
            await UpsertAppSettingsAsync(userId, request.AppSettings);

        await _db.SaveChangesAsync();

        return NoContent();
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private Guid GetUserId()
    {
        var sub = User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new InvalidOperationException("User ID claim missing.");
        return Guid.Parse(sub);
    }

    private async Task UpsertGameRecordsAsync(Guid userId, List<SyncPushItem> items)
    {
        if (items.Count == 0) return;

        var ids = items.Select(i => i.Id).ToList();
        var existingById = await _db.GameRecords
            .IgnoreQueryFilters()
            .Where(g => g.UserId == userId && ids.Contains(g.Id))
            .ToDictionaryAsync(g => g.Id);

        foreach (var item in items)
        {
            existingById.TryGetValue(item.Id, out var existing);

            if (existing is null)
            {
                _db.GameRecords.Add(new GameRecordEntity
                {
                    Id = item.Id,
                    UserId = userId,
                    Data = item.Data,
                    UpdatedAt = item.UpdatedAt.ToUniversalTime(),
                    ServerUpdatedAt = DateTime.UtcNow,
                    DeletedAt = item.Deleted ? item.UpdatedAt.ToUniversalTime() : null,
                });
            }
            else if (item.UpdatedAt.ToUniversalTime() >= existing.UpdatedAt)
            {
                existing.Data = item.Data;
                existing.UpdatedAt = item.UpdatedAt.ToUniversalTime();
                existing.ServerUpdatedAt = DateTime.UtcNow;
                existing.DeletedAt = item.Deleted ? item.UpdatedAt.ToUniversalTime() : null;
            }
        }
    }

    private async Task UpsertSideboardDecksAsync(Guid userId, List<SyncPushItem> items)
    {
        if (items.Count == 0) return;

        var ids = items.Select(i => i.Id).ToList();
        var existingById = await _db.SideboardDecks
            .IgnoreQueryFilters()
            .Where(s => s.UserId == userId && ids.Contains(s.Id))
            .ToDictionaryAsync(s => s.Id);

        foreach (var item in items)
        {
            existingById.TryGetValue(item.Id, out var existing);

            if (existing is null)
            {
                _db.SideboardDecks.Add(new SideboardDeckEntity
                {
                    Id = item.Id,
                    UserId = userId,
                    Data = item.Data,
                    UpdatedAt = item.UpdatedAt.ToUniversalTime(),
                    ServerUpdatedAt = DateTime.UtcNow,
                    DeletedAt = item.Deleted ? item.UpdatedAt.ToUniversalTime() : null,
                });
            }
            else if (item.UpdatedAt.ToUniversalTime() >= existing.UpdatedAt)
            {
                existing.Data = item.Data;
                existing.UpdatedAt = item.UpdatedAt.ToUniversalTime();
                existing.ServerUpdatedAt = DateTime.UtcNow;
                existing.DeletedAt = item.Deleted ? item.UpdatedAt.ToUniversalTime() : null;
            }
        }
    }

    private async Task UpsertAppSettingsAsync(Guid userId, SyncPushItem item)
    {
        var existing = await _db.AppSettings
            .FirstOrDefaultAsync(a => a.UserId == userId);

        if (existing is null)
        {
            _db.AppSettings.Add(new AppSettingsEntity
            {
                UserId = userId,
                Data = item.Data,
                UpdatedAt = item.UpdatedAt.ToUniversalTime(),
                ServerUpdatedAt = DateTime.UtcNow,
            });
        }
        else if (item.UpdatedAt.ToUniversalTime() >= existing.UpdatedAt)
        {
            existing.Data = item.Data;
            existing.UpdatedAt = item.UpdatedAt.ToUniversalTime();
            existing.ServerUpdatedAt = DateTime.UtcNow;
        }
    }
}
