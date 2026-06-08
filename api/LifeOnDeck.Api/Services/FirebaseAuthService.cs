using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace LifeOnDeck.Api.Services;

public class FirebaseAuthService(
    IHttpClientFactory httpClientFactory,
    IConfiguration configuration,
    ILogger<FirebaseAuthService> logger)
{
    private static readonly SemaphoreSlim KeyLock = new(1, 1);
    private static IList<JsonWebKey>? _cachedKeys;
    private static DateTime _keysExpiry = DateTime.MinValue;

    private const string FirebaseJwksUrl =
        "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

    public async Task<(string Sub, string Email, string Name)?> ValidateFirebaseTokenAsync(string idToken)
    {
        var projectId = configuration["Firebase:ProjectId"]
            ?? throw new InvalidOperationException("Firebase:ProjectId is not configured.");

        try
        {
            var keys = await GetPublicKeysAsync();
            var handler = new JsonWebTokenHandler();
            var result = await handler.ValidateTokenAsync(idToken, new TokenValidationParameters
            {
                ValidIssuer = $"https://securetoken.google.com/{projectId}",
                ValidAudience = projectId,
                IssuerSigningKeys = keys,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ClockSkew = TimeSpan.FromSeconds(30),
            });

            if (!result.IsValid)
            {
                logger.LogWarning("Firebase token invalid: {Reason}", result.Exception?.Message);
                return null;
            }

            result.Claims.TryGetValue("sub", out var sub);
            result.Claims.TryGetValue("email", out var email);
            result.Claims.TryGetValue("name", out var name);

            return sub?.ToString() is { Length: > 0 } subStr
                ? (subStr, email?.ToString() ?? string.Empty, name?.ToString() ?? string.Empty)
                : null;
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Firebase token validation threw");
            return null;
        }
    }

    private async Task<IList<JsonWebKey>> GetPublicKeysAsync()
    {
        if (_cachedKeys is not null && DateTime.UtcNow < _keysExpiry)
            return _cachedKeys;

        await KeyLock.WaitAsync();
        try
        {
            if (_cachedKeys is not null && DateTime.UtcNow < _keysExpiry)
                return _cachedKeys;

            var client = httpClientFactory.CreateClient();
            var json = await client.GetStringAsync(FirebaseJwksUrl);
            _cachedKeys = new JsonWebKeySet(json).Keys;
            _keysExpiry = DateTime.UtcNow.AddHours(1);
            return _cachedKeys;
        }
        finally
        {
            KeyLock.Release();
        }
    }
}
