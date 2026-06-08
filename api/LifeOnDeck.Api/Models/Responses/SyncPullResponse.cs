namespace LifeOnDeck.Api.Models.Responses;

public class SyncPullResponse
{
    public DateTime ServerTime { get; set; }
    public List<SyncItemDto> GameRecords { get; set; } = [];
    public List<SyncItemDto> SideboardDecks { get; set; } = [];
    public SyncItemDto? AppSettings { get; set; }
}

public class SyncItemDto
{
    public string Id { get; set; } = string.Empty;
    public string Data { get; set; } = "{}";
    public DateTime UpdatedAt { get; set; }
    public bool Deleted { get; set; }
}
