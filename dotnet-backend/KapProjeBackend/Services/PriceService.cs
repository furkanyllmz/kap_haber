using KapProjeBackend.Models;
using Microsoft.Extensions.Options;
using MongoDB.Driver;

namespace KapProjeBackend.Services;

public class PriceService
{
    private readonly IMongoCollection<PriceItem> _pricesCollection;

    public PriceService(IOptions<MongoDbSettings> mongoDbSettings)
    {
        var mongoClient = new MongoClient(mongoDbSettings.Value.ConnectionString);
        var mongoDatabase = mongoClient.GetDatabase(mongoDbSettings.Value.DatabaseName);
        _pricesCollection = mongoDatabase.GetCollection<PriceItem>("prices");
    }

    public async Task<PriceItem?> GetByTickerAsync(string ticker)
    {
        var filter = Builders<PriceItem>.Filter.Eq(x => x.Ticker, ticker.ToUpper());
        return await _pricesCollection.Find(filter).FirstOrDefaultAsync();
    }
    
    public async Task<List<PriceItem>> GetAllAsync()
    {
        return await _pricesCollection.Find(_ => true).ToListAsync();
    }

    public async Task<object> GetMarketSummaryAsync()
    {
        var allPrices = await _pricesCollection.Find(_ => true).ToListAsync();
        
        int rising = 0;
        int falling = 0;
        int neutral = 0;

        foreach (var item in allPrices)
        {
            if (item.ExtraElements != null && item.ExtraElements.TryGetValue("DailyChange", out var changeVal)) 
            {
               double change = Convert.ToDouble(changeVal);
               if (change > 0) rising++;
               else if (change < 0) falling++;
               else neutral++;
            }
            else 
            {
                neutral++;
            }
        }

        return new { rising, falling, neutral, total = allPrices.Count };
    }
}
