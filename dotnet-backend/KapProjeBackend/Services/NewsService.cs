using MongoDB.Driver;
using KapProjeBackend.Models;
using Microsoft.Extensions.Options;

namespace KapProjeBackend.Services;

public class NewsService
{
    private readonly IMongoCollection<NewsItem> _newsCollection;
    private readonly IWebHostEnvironment _env;
    private readonly string _baseUrl;

    public NewsService(IOptions<MongoDbSettings> mongoSettings, IWebHostEnvironment env, IConfiguration configuration)
    {
        var client = new MongoClient(mongoSettings.Value.ConnectionString);
        var database = client.GetDatabase(mongoSettings.Value.DatabaseName);
        _newsCollection = database.GetCollection<NewsItem>(mongoSettings.Value.NewsCollectionName);
        _env = env;
        // Production: use configured BaseUrl, Development: fallback to localhost
        _baseUrl = configuration["BaseUrl"] ?? "http://localhost:5296";
    }

    /// <summary>
    /// Maps category name to banner image URL
    /// </summary>
    private string MapCategoryToImageUrl(string? category)
    {
        var baseUrl = $"{_baseUrl}/banners";
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
    /// Tries to find a custom-generated image for this news item in news/images folder
    /// Pattern: TICKER___date__ _YYYY-MM-DD__...
    /// </summary>
    private string? TryGetCustomImageUrl(NewsItem item)
    {
        try
        {
            // news/images klasörünün yolu (Program.cs'de ayarladığımız gibi)
            var newsImagesPath = Path.Combine(_env.ContentRootPath, "..", "..", "news", "images");
            newsImagesPath = Path.GetFullPath(newsImagesPath);

            if (!Directory.Exists(newsImagesPath))
            {
                return null;
            }

            var ticker = item.PrimaryTicker?.ToUpper() ?? "";
            var date = item.PublishedAt?.Date ?? "";

            if (string.IsNullOrEmpty(ticker) || string.IsNullOrEmpty(date))
            {
                return null;
            }

            // Dosya adı prefix'i: "TICKER___date__ _YYYY-MM-DD__"
            // Örnek: AGROT___date__ _2026-01-07__...
            var prefix = $"{ticker}___date__ _{date}__";

            // Klasördeki dosyaları tara ve prefix ile başlayanı bul
            var files = Directory.GetFiles(newsImagesPath, "*.png")
                                 .Select(Path.GetFileName)
                                 .Where(f => f != null && f.StartsWith(prefix, StringComparison.OrdinalIgnoreCase))
                                 .ToList();

            if (files.Count > 0)
            {
                // İlk eşleşeni döndür (aynı ticker+tarih için birden fazla olabilir)
                var fileName = files.First()!;
                // URL encode yap (dosya adında özel karakterler var)
                return $"{_baseUrl}/news-images/{Uri.EscapeDataString(fileName)}";
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[NewsService] Custom image lookup error: {ex.Message}");
        }

        return null;
    }

    /// <summary>
    /// Applies ImageUrl to a news item - prefers custom image, falls back to category banner
    /// </summary>
    private NewsItem ApplyImageUrl(NewsItem item)
    {
        // 1. Önce custom haber görselini dene
        var customImage = TryGetCustomImageUrl(item);
        if (customImage != null)
        {
            item.ImageUrl = customImage;
            return item;
        }

        // 2. Custom yoksa kategori banner'ına fallback
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
