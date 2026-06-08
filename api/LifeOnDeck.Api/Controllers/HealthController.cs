using LifeOnDeck.Api.Data;
using Microsoft.AspNetCore.Mvc;

namespace LifeOnDeck.Api.Controllers;

[ApiController]
[Route("api/v1/health")]
public class HealthController(AppDbContext db, ILogger<HealthController> logger) : ControllerBase
{
    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        bool dbOk;
        try
        {
            dbOk = await db.Database.CanConnectAsync(ct);
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Health check: DB connection probe failed");
            dbOk = false;
        }

        var payload = new
        {
            status = dbOk ? "ok" : "degraded",
            time = now,
            db = dbOk ? "ok" : "unreachable",
        };

        return dbOk
            ? Ok(payload)
            : StatusCode(StatusCodes.Status503ServiceUnavailable, payload);
    }
}
