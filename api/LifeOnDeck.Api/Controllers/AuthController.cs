using LifeOnDeck.Api.Data;
using LifeOnDeck.Api.Data.Entities;
using LifeOnDeck.Api.Models.Requests;
using LifeOnDeck.Api.Models.Responses;
using LifeOnDeck.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;

namespace LifeOnDeck.Api.Controllers;

[ApiController]
[Route("api/v1/auth")]
[EnableRateLimiting("auth-policy")]
public class AuthController(
    AppDbContext db,
    FirebaseAuthService firebaseAuthService,
    JwtService jwtService,
    ILogger<AuthController> logger) : ControllerBase
{
    [HttpPost("firebase")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> FirebaseAuth([FromBody] GoogleAuthRequest request)
    {
        var payload = await firebaseAuthService.ValidateFirebaseTokenAsync(request.IdToken);
        if (payload is null)
        {
            logger.LogWarning("Firebase token validation failed");
            return Unauthorized(new { message = "Invalid Firebase ID token." });
        }

        var (sub, email, name) = payload.Value;

        var user = await db.Users.FirstOrDefaultAsync(u => u.GoogleId == sub);

        if (user is null)
        {
            user = new User
            {
                Id = Guid.NewGuid(),
                GoogleId = sub,
                Email = email,
                DisplayName = name.Length > 0 ? name : email,
                CreatedAt = DateTime.UtcNow,
            };
            db.Users.Add(user);
            logger.LogInformation("Created user {UserId} for Firebase subject {Sub}", user.Id, sub);
        }
        else
        {
            user.Email = email;
            user.DisplayName = name.Length > 0 ? name : email;
        }

        await db.SaveChangesAsync();
        var token = jwtService.GenerateToken(user);

        return Ok(new AuthResponse
        {
            Token = token,
            User = new UserDto { Id = user.Id, Email = user.Email, DisplayName = user.DisplayName },
        });
    }
}
