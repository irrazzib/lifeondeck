using LifeOnDeck.Api.Data.Entities;
using Microsoft.EntityFrameworkCore;

namespace LifeOnDeck.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<GameRecordEntity> GameRecords => Set<GameRecordEntity>();
    public DbSet<SideboardDeckEntity> SideboardDecks => Set<SideboardDeckEntity>();
    public DbSet<AppSettingsEntity> AppSettings => Set<AppSettingsEntity>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(u => u.Id);
            entity.Property(u => u.Id).ValueGeneratedOnAdd();
            entity.HasIndex(u => u.GoogleId).IsUnique();
            entity.HasIndex(u => u.Email).IsUnique();
            entity.Property(u => u.CreatedAt)
                  .HasDefaultValueSql("NOW()");
        });

        // GameRecordEntity
        modelBuilder.Entity<GameRecordEntity>(entity =>
        {
            entity.HasKey(g => g.Id);
            entity.HasIndex(g => new { g.UserId, g.ServerUpdatedAt });

            entity.HasOne(g => g.User)
                  .WithMany(u => u.GameRecords)
                  .HasForeignKey(g => g.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            // Soft delete filter
            entity.HasQueryFilter(g => g.DeletedAt == null);
        });

        // SideboardDeckEntity
        modelBuilder.Entity<SideboardDeckEntity>(entity =>
        {
            entity.HasKey(s => s.Id);
            entity.HasIndex(s => new { s.UserId, s.ServerUpdatedAt });

            entity.HasOne(s => s.User)
                  .WithMany(u => u.SideboardDecks)
                  .HasForeignKey(s => s.UserId)
                  .OnDelete(DeleteBehavior.Cascade);

            // Soft delete filter
            entity.HasQueryFilter(s => s.DeletedAt == null);
        });

        // AppSettingsEntity
        modelBuilder.Entity<AppSettingsEntity>(entity =>
        {
            entity.HasKey(a => a.UserId);

            entity.HasOne(a => a.User)
                  .WithOne(u => u.AppSettings)
                  .HasForeignKey<AppSettingsEntity>(a => a.UserId)
                  .OnDelete(DeleteBehavior.Cascade);
        });
    }
}
