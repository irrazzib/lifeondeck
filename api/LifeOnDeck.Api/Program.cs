using System.Text;
using System.Text.RegularExpressions;
using System.Threading.RateLimiting;
using LifeOnDeck.Api.Data;
using LifeOnDeck.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

// ─── Kestrel limits ──────────────────────────────────────────────────────────
builder.WebHost.ConfigureKestrel(opts =>
    opts.Limits.MaxRequestBodySize = 5 * 1024 * 1024); // 5 MB

// ─── Database ────────────────────────────────────────────────────────────────
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

// ─── Authentication / JWT ────────────────────────────────────────────────────
var jwtSection = builder.Configuration.GetSection("Jwt");
var secretKey = jwtSection["SecretKey"]
    ?? throw new InvalidOperationException(
        "Jwt:SecretKey is not configured. Set the JWT__SECRETKEY environment variable " +
        "(or Jwt:SecretKey in appsettings.Development.json for local dev).");
if (secretKey.Length < 32)
    throw new InvalidOperationException(
        $"Jwt:SecretKey must be at least 32 characters long (got {secretKey.Length}).");

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtSection["Issuer"],
            ValidAudience = jwtSection["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });

builder.Services.AddAuthorization();

// ─── App Services ─────────────────────────────────────────────────────────────
builder.Services.AddHttpClient();
builder.Services.AddScoped<JwtService>();
builder.Services.AddScoped<FirebaseAuthService>();

// ─── Controllers + OpenAPI ───────────────────────────────────────────────────
builder.Services.AddControllers();
builder.Services.AddOpenApi();

// ─── CORS (whitelist from Cors:AllowedOrigins) ───────────────────────────────
// Empty list → all origins blocked. Entries support `*` glob (e.g. "http://localhost:*",
// "https://*.lifeondeck.app"). Exact strings are matched literally.
var corsOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? Array.Empty<string>();

builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
    {
        if (corsOrigins.Length == 0)
        {
            policy.SetIsOriginAllowed(_ => false);
        }
        else if (corsOrigins.Any(o => o.Contains('*')))
        {
            var patterns = corsOrigins.Select(o => new Regex(
                "^" + Regex.Escape(o).Replace("\\*", "[^/]*") + "$",
                RegexOptions.IgnoreCase | RegexOptions.Compiled)).ToArray();
            policy.SetIsOriginAllowed(origin => patterns.Any(p => p.IsMatch(origin)));
        }
        else
        {
            policy.WithOrigins(corsOrigins)
                  .SetIsOriginAllowedToAllowWildcardSubdomains();
        }
        // Sync API uses GET/POST + Authorization/Content-Type. Keep permissive on
        // method/header for now; restrict if surface narrows.
        policy.AllowAnyMethod().AllowAnyHeader();
    }));

// ─── Rate limiting ───────────────────────────────────────────────────────────
// Per-IP fixed windows. Policies applied via [EnableRateLimiting] on controllers.
builder.Services.AddRateLimiter(opts =>
{
    opts.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    static string IpKey(HttpContext ctx) =>
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown";

    opts.AddPolicy("sync-policy", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: IpKey(ctx),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            }));

    opts.AddPolicy("auth-policy", ctx =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: IpKey(ctx),
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            }));
});

// ─── Build ────────────────────────────────────────────────────────────────────
var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();
app.UseHttpsRedirection();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();
app.MapControllers();

app.Run();
