using System.Text.Json.Serialization;

namespace KapProjeBackend.Models;

public class ChartData
{
    [JsonPropertyName("date")]
    public string Date { get; set; } = string.Empty;

    [JsonPropertyName("price")]
    public double Price { get; set; }
}
