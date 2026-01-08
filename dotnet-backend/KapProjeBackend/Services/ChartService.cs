using System.Text.Json;
using KapProjeBackend.Models;

namespace KapProjeBackend.Services;

public class ChartService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<ChartService> _logger;

    public ChartService(HttpClient httpClient, ILogger<ChartService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _httpClient.DefaultRequestHeaders.Add("User-Agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");
        _httpClient.DefaultRequestHeaders.Add("Accept", "*/*");
        _httpClient.DefaultRequestHeaders.Add("Accept-Language", "en-US,en;q=0.9,tr;q=0.8");
    }

    public async Task<List<ChartData>> GetChartDataAsync(string symbol, string time)
    {
        try 
        {
            var url = $"https://www.getmidas.com/wp-json/midas-api/v1/midas_stock_time?code={symbol}&time={time}";
            var response = await _httpClient.GetAsync(url);
            
            if (!response.IsSuccessStatusCode)
            {
                _logger.LogWarning($"Midas API error: {response.StatusCode} for {symbol}");
                return new List<ChartData>();
            }

            var content = await response.Content.ReadAsStringAsync();
            
            // Expected Midas response is object with "data" property which is an array
            // Structure: { "data": [ { "date": "...", "close": 12.34 }, ... ] }
            // Or sometimes direct array? Let's handle both or use dynamic to be safe first then map.
            
            using var doc = JsonDocument.Parse(content);
            var root = doc.RootElement;
            
            // Check if root is a string (double encoded JSON)
            if (root.ValueKind == JsonValueKind.String)
            {
                var innerContent = root.GetString();
                if (!string.IsNullOrEmpty(innerContent))
                {
                    using var innerDoc = JsonDocument.Parse(innerContent);
                    root = innerDoc.RootElement.Clone(); // Clone finding
                }
            }

            var result = new List<ChartData>();

            if (root.TryGetProperty("dates", out var datesProp) && root.TryGetProperty("data", out var dataProp))
            {
                var dates = datesProp.EnumerateArray().ToList();
                var prices = dataProp.EnumerateArray().ToList();

                if (dates.Count == prices.Count)
                {
                    for (int i = 0; i < dates.Count; i++)
                    {
                        // Convert timestamp to Turkey timezone (UTC+3)
                        // Assuming Midas sends milliseconds timestamp in UTC
                        long timestamp = dates[i].GetInt64();
                        var utcDateTime = DateTimeOffset.FromUnixTimeMilliseconds(timestamp);
                        var turkeyTimeZone = TimeZoneInfo.FindSystemTimeZoneById("Europe/Istanbul");
                        var turkeyDateTime = TimeZoneInfo.ConvertTime(utcDateTime, turkeyTimeZone);
                        
                        // Günlük (1G) için saat:dakika dahil, diğerleri için sadece tarih
                        string dateStr;
                        if (time == "1G")
                        {
                            // Günlük: tam tarih ve saat göster
                            dateStr = turkeyDateTime.ToString("yyyy-MM-dd HH:mm");
                        }
                        else if (time == "1H" || time == "1A")
                        {
                            // Haftalık/Aylık: sadece tarih
                            dateStr = turkeyDateTime.ToString("yyyy-MM-dd");
                        }
                        else
                        {
                            // Yıllık: sadece tarih
                            dateStr = turkeyDateTime.ToString("yyyy-MM-dd");
                        }
                        
                        double price = 0;
                        if (prices[i].ValueKind == JsonValueKind.Number)
                            price = prices[i].GetDouble();

                        result.Add(new ChartData { Date = dateStr, Price = price });
                    }
                }
            }

            return result;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Error fetching chart data for {symbol}");
            return new List<ChartData>();
        }
    }
}
