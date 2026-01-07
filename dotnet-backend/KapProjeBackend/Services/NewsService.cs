using MongoDB.Driver;
using KapProjeBackend.Models;
using Microsoft.Extensions.Options;

namespace KapProjeBackend.Services;

public class NewsService
{
    private readonly IMongoCollection<NewsItem> _newsCollection;
    private readonly IWebHostEnvironment _env;

    public NewsService(IOptions<MongoDbSettings> mongoSettings, IWebHostEnvironment env)
    {
        var client = new MongoClient(mongoSettings.Value.ConnectionString);
        var database = client.GetDatabase(mongoSettings.Value.DatabaseName);
        _newsCollection = database.GetCollection<NewsItem>(mongoSettings.Value.NewsCollectionName);
        _env = env;
    }

    /// <summary>
    /// Maps category name to banner image URL
    /// </summary>
    private string MapCategoryToImageUrl(string? category)
    {
        const string baseUrl = "http://localhost:5296/banners";
        const string defaultImage = "diğer.jpg"; // Fallback image in banners root or Diğer folder

        // 1. Kategori temizliği
        var catName = (category ?? "Diğer").Trim();
        
        // 2. Kategori -> Klasör eşleşmesi (Küçük harf -> Gerçek Klasör Adı)
        // wwwroot/banners altında bu klasörlerin tam olarak bu isimle yaratılmış olması gerekir.
        var folderMap = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "halka arz", "Halka Arz" },
            { "sermaye", "Sermaye" },
            { "sözleşme", "Sözleşme" },
            { "spk", "SPK" },
            { "yatırım", "Yatırım" },
            { "diğer", "Diğer" }
        };

        // Gelen kategori haritada yoksa "Diğer" kullan
        if (!folderMap.TryGetValue(catName, out var targetFolder))
        {
            targetFolder = "Diğer";
        }

        try 
        {
            // 3. Fiziksel yol kontrolü
            var bannersPath = Path.Combine(_env.WebRootPath, "banners");
            var targetPath = Path.Combine(bannersPath, targetFolder);

            if (Directory.Exists(targetPath))
            {
                // Klasördeki resimleri bul (.jpg, .png, .jpeg)
                var files = Directory.GetFiles(targetPath, "*.*")
                                     .Where(f => f.EndsWith(".jpg", StringComparison.OrdinalIgnoreCase) || 
                                                 f.EndsWith(".png", StringComparison.OrdinalIgnoreCase) || 
                                                 f.EndsWith(".jpeg", StringComparison.OrdinalIgnoreCase))
                                     .ToArray();

                if (files.Length > 0)
                {
                    // Random seçim
                    var randomFile = files[new Random().Next(files.Length)];
                    var fileName = Path.GetFileName(randomFile);
                    
                    // URL oluştur: encoding gerekebilir (boşluklar vs için)
                    // Uri.EscapeDataString kullanımı dosya adındaki boşlukları %20 yapar
                    return $"{baseUrl}/{Uri.EscapeDataString(targetFolder)}/{Uri.EscapeDataString(fileName)}";
                }
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[NewsService] Banner selection error: {ex.Message}");
        }

        // Fallback: Eskisi gibi root'ta bir dosya veya Diğer klasöründen bir dosya dönebiliriz.
        // Hata durumunda veya dosya yoksa güvenli liman:
        return $"{baseUrl}/{defaultImage}";
    }

    /// <summary>
    /// Applies ImageUrl to a news item based on its category
    /// </summary>
    private NewsItem ApplyImageUrl(NewsItem item)
    {
        item.ImageUrl = MapCategoryToImageUrl(item.Category);
        return item;
    }

    /// <summary>
    /// Tüm haberleri getir (sayfalı)
    /// </summary>
    public async Task<List<NewsItem>> GetAllAsync(int page = 1, int pageSize = 20)
    {
        var items = await _newsCollection
            .Find(_ => true)
            .SortByDescending(n => n.PublishedAt!.Date)
            .Skip((page - 1) * pageSize)
            .Limit(pageSize)
            .ToListAsync();
        
        return items.Select(ApplyImageUrl).ToList();
    }

    /// <summary>
    /// Belirli bir ticker'a ait haberleri getir
    /// </summary>
    public async Task<List<NewsItem>> GetByTickerAsync(string ticker, int page = 1, int pageSize = 20)
    {
        var filter = Builders<NewsItem>.Filter.AnyEq(n => n.RelatedTickers, ticker.ToUpper());
        
        var items = await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Date)
            .Skip((page - 1) * pageSize)
            .Limit(pageSize)
            .ToListAsync();
        
        return items.Select(ApplyImageUrl).ToList();
    }

    /// <summary>
    /// Bugünün haberlerini getir
    /// </summary>
    public async Task<List<NewsItem>> GetTodayAsync()
    {
        var today = DateTime.Now.ToString("yyyy-MM-dd");
        var filter = Builders<NewsItem>.Filter.Eq("published_at.date", today);
        
        var items = await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Time)
            .ToListAsync();
        
        return items.Select(ApplyImageUrl).ToList();
    }

    /// <summary>
    /// Belirli bir tarihteki haberleri getir
    /// </summary>
    public async Task<List<NewsItem>> GetByDateAsync(string date)
    {
        var filter = Builders<NewsItem>.Filter.Eq("published_at.date", date);
        
        var items = await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Time)
            .ToListAsync();
        
        return items.Select(ApplyImageUrl).ToList();
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
        
        var items = await _newsCollection
            .Find(filter)
            .SortByDescending(n => n.PublishedAt!.Date)
            .ToListAsync();
        
        return items.Select(ApplyImageUrl).ToList();
    }

    /// <summary>
    /// Son N haberi getir
    /// </summary>
    public async Task<List<NewsItem>> GetLatestAsync(int count = 10)
    {
        var items = await _newsCollection
            .Find(_ => true)
            .SortByDescending(n => n.PublishedAt!.Date)
            .ThenByDescending(n => n.PublishedAt!.Time)
            .Limit(count)
            .ToListAsync();
        
        return items.Select(ApplyImageUrl).ToList();
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

    /// <summary>
    /// ID'ye göre haber getir
    /// </summary>
    public async Task<NewsItem?> GetByIdAsync(string id)
    {
        var item = await _newsCollection.Find(n => n.Id == id).FirstOrDefaultAsync();
        if (item != null)
        {
            return ApplyImageUrl(item);
        }
        return null;
    }
}
