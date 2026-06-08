namespace LifeOnDeck.Api.Models.Requests;

public class SyncPushRequest
{
    public List<SyncPushItem> GameRecords { get; set; } = [];
    public List<SyncPushItem> SideboardDecks { get; set; } = [];
    public SyncPushItem? AppSettings { get; set; }
}
