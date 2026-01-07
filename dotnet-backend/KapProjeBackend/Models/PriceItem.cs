using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace KapProjeBackend.Models;

[BsonIgnoreExtraElements]
public class PriceItem
{
    [BsonId]
    [BsonRepresentation(BsonType.ObjectId)]
    public string? Id { get; set; }

    [BsonElement("Code")]
    public string? Ticker { get; set; }

    [BsonElement("_updated_at")]
    public DateTime UpdatedAt { get; set; }

    // Catch-all for other fields
    [BsonExtraElements]
    public Dictionary<string, object>? ExtraElements { get; set; }
}
