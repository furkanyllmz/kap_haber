using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace KapProjeBackend.Models;

/// <summary>
/// MongoDB'deki haber dökümanını temsil eder
/// </summary>
[BsonIgnoreExtraElements]
public class NewsItem
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("primary_ticker")]
    public string? PrimaryTicker { get; set; }

    [BsonElement("publisher_ticker")]
    public string? PublisherTicker { get; set; }

    [BsonElement("related_tickers")]
    public List<string>? RelatedTickers { get; set; }

    [BsonElement("published_at")]
    public PublishedAt? PublishedAt { get; set; }

    [BsonElement("category")]
    public string? Category { get; set; }

    [BsonElement("newsworthiness")]
    public double Newsworthiness { get; set; }

    [BsonElement("headline")]
    public string? Headline { get; set; }

    [BsonElement("facts")]
    public List<Fact>? Facts { get; set; }

    [BsonElement("key_numbers")]
    public KeyNumbers? KeyNumbers { get; set; }

    [BsonElement("tweet")]
    public TweetData? Tweet { get; set; }

    [BsonElement("seo")]
    public SeoData? Seo { get; set; }

    [BsonElement("visual_prompt")]
    public string? VisualPrompt { get; set; }

    [BsonElement("publish_target")]
    public string? PublishTarget { get; set; }

    [BsonElement("url")]
    public string? Url { get; set; }

    [BsonElement("ticker")]
    public string? Ticker { get; set; }

    [BsonElement("_inserted_at")]
    public string? InsertedAt { get; set; }
}

[BsonIgnoreExtraElements]
public class PublishedAt
{
    [BsonElement("date")]
    public string? Date { get; set; }

    [BsonElement("time")]
    public string? Time { get; set; }

    [BsonElement("timezone")]
    public string? Timezone { get; set; }
}

[BsonIgnoreExtraElements]
public class Fact
{
    [BsonElement("k")]
    public string? Key { get; set; }

    [BsonElement("v")]
    public string? Value { get; set; }
}

[BsonIgnoreExtraElements]
public class KeyNumbers
{
    [BsonElement("amount_raw")]
    public string? AmountRaw { get; set; }

    [BsonElement("ratio_to_market_cap")]
    public string? RatioToMarketCap { get; set; }

    [BsonElement("ratio_to_revenue")]
    public string? RatioToRevenue { get; set; }
}

[BsonIgnoreExtraElements]
public class TweetData
{
    [BsonElement("text")]
    public string? Text { get; set; }

    [BsonElement("hashtags")]
    public List<string>? Hashtags { get; set; }

    [BsonElement("disclaimer")]
    public string? Disclaimer { get; set; }
}

[BsonIgnoreExtraElements]
public class SeoData
{
    [BsonElement("title")]
    public string? Title { get; set; }

    [BsonElement("meta_description")]
    public string? MetaDescription { get; set; }

    [BsonElement("article_md")]
    public string? ArticleMd { get; set; }
}
