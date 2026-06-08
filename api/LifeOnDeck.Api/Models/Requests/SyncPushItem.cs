namespace LifeOnDeck.Api.Models.Requests;

public class SyncPushItem
{
    public string Id { get; set; } = string.Empty;
    public string Data { get; set; } = "{}";
    public DateTime UpdatedAt { get; set; }
    public bool Deleted { get; set; }
}
