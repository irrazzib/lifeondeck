namespace LifeOnDeck.Api.Data.Entities;

public class AppSettingsEntity
{
    public Guid UserId { get; set; }  // PK
    public User User { get; set; } = null!;
    public string Data { get; set; } = "{}";
    public DateTime UpdatedAt { get; set; }      // client clock — used for LWW conflict resolution
    public DateTime ServerUpdatedAt { get; set; } // server clock — used as the sync cursor
}
