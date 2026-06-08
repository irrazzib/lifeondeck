namespace LifeOnDeck.Api.Data.Entities;

public class User
{
    public Guid Id { get; set; }
    public string GoogleId { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string DisplayName { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public ICollection<GameRecordEntity> GameRecords { get; set; } = [];
    public ICollection<SideboardDeckEntity> SideboardDecks { get; set; } = [];
    public AppSettingsEntity? AppSettings { get; set; }
}
