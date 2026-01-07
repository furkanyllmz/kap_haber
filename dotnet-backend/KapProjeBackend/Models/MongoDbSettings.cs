namespace KapProjeBackend.Models;

public class MongoDbSettings
{
    public string ConnectionString { get; set; } = "mongodb://localhost:27017";
    public string DatabaseName { get; set; } = "kap_news";
    public string NewsCollectionName { get; set; } = "news_items";
}
