using MongoDB.Driver;
using KapProjeBackend.Models;
using Microsoft.Extensions.Options;

namespace KapProjeBackend.Services;

public class NewsService
{
    private readonly IMongoCollection<NewsItem> _newsCollection;

    public NewsService(IOptions<MongoDbSettings> mongoSettings)
    {
        var client = new MongoClient(mongoSettings.Value.ConnectionString);
        var database = client.GetDatabase(mongoSettings.Value.DatabaseName);
        _newsCollection = database.GetCollection<NewsItem>(mongoSettings.Value.NewsCollectionName);
    }

    /// <summary>
    /// Tüm haberleri getir (sayfalı)
    /// </summary>
    public async Task<List<NewsItem>> GetAllAsync(int page = 1, int pageSize = 20)
    {
        return await _newsCollection
            .Find(_ => true)
            .SortByDescending(n => n.PublishedAt!.Date)
            .Skip((page - 1) * pageSize)
            .Limit(pageSize)
            .ToListAsync();
    }

    /// <summary>
    /// Belirli bir ticker'a ait haberleri getir
    /// </summary>
    public async Task<List<NewsItem>> GetByTickerAsync(string ticker, int page = 1, int pageSize = 20)
    {
        var filter = Builders<NewsItem>.Filter.AnyEq(n => n.RelatedTickers, ticker.ToUpper());
        
        return await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Date)
            .Skip((page - 1) * pageSize)
            .Limit(pageSize)
            .ToListAsync();
    }

    /// <summary>
    /// Bugünün haberlerini getir
    /// </summary>
    public async Task<List<NewsItem>> GetTodayAsync()
    {
        var today = DateTime.Now.ToString("yyyy-MM-dd");
        var filter = Builders<NewsItem>.Filter.Eq("published_at.date", today);
        
        return await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Time)
            .ToListAsync();
    }

    /// <summary>
    /// Belirli bir tarihteki haberleri getir
    /// </summary>
    public async Task<List<NewsItem>> GetByDateAsync(string date)
    {
        var filter = Builders<NewsItem>.Filter.Eq("published_at.date", date);
        
        return await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Time)
            .ToListAsync();
    }

    /// <summary>
    /// Tarih aralığındaki haberleri getir
    /// </summary>
    public async Task<List<NewsItem>> GetByDateRangeAsync(string fromDate, string toDate)
    {
        var filter = Builders<NewsItem>.Filter.And(
            Builders<NewsItem>.Filter.Gte("published_at.date", fromDate),
            Builders<NewsItem>.Filter.Lte("published_at.date", toDate)
        );
        
        return await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Date)
            .ToListAsync();
    }

    /// <summary>
    /// Son N haberi getir
    /// </summary>
    public async Task<List<NewsItem>> GetLatestAsync(int count = 10)
    {
        return await _newsCollection
            .Find(_ => true)
            .SortByDescending(n => n.PublishedAt!.Date)
            .ThenByDescending(n => n.PublishedAt!.Time)
            .Limit(count)
            .ToListAsync();
    }

    /// <summary>
    /// Toplam haber sayısını getir
    /// </summary>
    public async Task<long> GetCountAsync()
    {
        return await _newsCollection.CountDocumentsAsync(_ => true);
    }

    /// <summary>
    /// Belirli ticker için haber sayısını getir
    /// </summary>
    public async Task<long> GetCountByTickerAsync(string ticker)
    {
        var filter = Builders<NewsItem>.Filter.AnyEq(n => n.RelatedTickers, ticker.ToUpper());
        return await _newsCollection.CountDocumentsAsync(filter);
    }
}
