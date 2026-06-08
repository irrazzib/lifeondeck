namespace LifeOnDeck.Api.Data.Entities;

public class GameRecordEntity
{
    public string Id { get; set; } = string.Empty;  // client-generated UUID
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;
    public string Data { get; set; } = "{}";  // JSON blob
    public DateTime UpdatedAt { get; set; }      // client clock — used for LWW conflict resolution
    public DateTime ServerUpdatedAt { get; set; } // server clock — used as the sync cursor
    public DateTime? DeletedAt { get; set; }
}
