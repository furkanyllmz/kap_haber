using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace KapProjeBackend.Models;

[BsonIgnoreExtraElements]
public class Ticker
{
    [BsonId]
    [BsonRepresentation(BsonType.String)]
    public string Id { get; set; } = null!; // Symbol

    [BsonElement("original_text")]
    public string OriginalText { get; set; } = null!; // Company Name
}
