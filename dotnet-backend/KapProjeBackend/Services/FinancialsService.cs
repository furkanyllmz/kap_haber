using System.Text.Json;
using MongoDB.Driver;
using KapProjeBackend.Models;
using Microsoft.Extensions.Options;

namespace KapProjeBackend.Services;

public class FinancialsService
{
    private readonly IMongoCollection<Ticker> _tickersCollection;
    private readonly string _financialsDir;

    public FinancialsService(IOptions<MongoDbSettings> mongoSettings)
    {
        var client = new MongoClient(mongoSettings.Value.ConnectionString);
        var database = client.GetDatabase(mongoSettings.Value.DatabaseName);
        _tickersCollection = database.GetCollection<Ticker>("tickers");
        
        // Define path to financials directory relative to backend execution path
        // Assuming backend is in /dotnet-backend/KapProjeBackend
        // Financials are in /daily_data_kap/financials
        _financialsDir = Path.Combine(Directory.GetCurrentDirectory(), "../../daily_data_kap/financials");
    }

    public async Task<CompanyDetailsDto> GetCompanyDetailsAsync(string symbol)
    {
        symbol = symbol.ToUpper().Trim();

        // 1. Get name from MongoDB
        var ticker = await _tickersCollection.Find(t => t.Id == symbol).FirstOrDefaultAsync();
        string companyName = ticker?.OriginalText ?? symbol;

        // 2. Read financials from JSON
        var financials = new Dictionary<string, object>();
        
        // Try exact match first: "{symbol}, {name}_financials.json"
        // Since name might contain special chars or be unknown, we iterate or try common patterns.
        // Actually, logic in Python was: f"{symbol}, {company_name}_financials.json"
        
        string filename = $"{symbol}, {companyName}_financials.json";
        string path = Path.Combine(_financialsDir, filename);

        // Fallback for just symbol
        if (!File.Exists(path))
        {
             path = Path.Combine(_financialsDir, $"{symbol}_financials.json");
        }
        
        // As a last robust check, search for file starting with "{symbol}, "
        if (!File.Exists(path))
        {
            try
            {
                if (Directory.Exists(_financialsDir))
                {
                    var files = Directory.GetFiles(_financialsDir, $"{symbol}, *_financials.json");
                    if (files.Length > 0)
                    {
                        path = files[0];
                    }
                }
            }
            catch { /* Ignore */ }
        }

        if (File.Exists(path))
        {
            try
            {
                var jsonString = await File.ReadAllTextAsync(path);
                // Use case-insensitive deserialization for flexibility
                 var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                financials = JsonSerializer.Deserialize<Dictionary<string, object>>(jsonString, options) ?? new();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Error reading financials for {symbol}: {ex.Message}");
            }
        }

        return new CompanyDetailsDto
        {
            Symbol = symbol,
            Name = companyName,
            Financials = financials
        };
    }
}
