using Microsoft.AspNetCore.Mvc;
using KapProjeBackend.Services;
using System.Text;
using System.Xml;

namespace KapProjeBackend.Controllers;

[ApiController]
public class SitemapController : ControllerBase
{
    private readonly NewsService _newsService;
    private readonly PriceService _priceService;
    private const string BaseUrl = "https://kaphaber.com";

    public SitemapController(NewsService newsService, PriceService priceService)
    {
        _newsService = newsService;
        _priceService = priceService;
    }

    [HttpGet("sitemap.xml")]
    public async Task<IActionResult> GetSitemap()
    {
        var sb = new StringBuilder();
        sb.AppendLine("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
        sb.AppendLine("<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">");

        // 1. Static Pages
        AddUrl(sb, BaseUrl, "1.0", "daily");
        AddUrl(sb, $"{BaseUrl}/companies", "0.8", "daily");
        AddUrl(sb, $"{BaseUrl}/about", "0.5", "monthly");

        // 2. Individual Stock Pages
        var prices = await _priceService.GetAllAsync();
        foreach (var price in prices)
        {
            if (!string.IsNullOrEmpty(price.Ticker))
            {
                AddUrl(sb, $"{BaseUrl}/companies/{price.Ticker}", "0.7", "daily");
            }
        }

        // 3. Latest News (Last 500 items)
        var latestNews = await _newsService.GetLatestAsync(500);
        foreach (var news in latestNews)
        {
            if (!string.IsNullOrEmpty(news.Id))
            {
                // Note: The frontend route for news detail is /news/{id}
                AddUrl(sb, $"{BaseUrl}/news/{news.Id}", "0.6", "weekly");
            }
        }

        sb.AppendLine("</urlset>");

        return Content(sb.ToString(), "application/xml", Encoding.UTF8);
    }

    private void AddUrl(StringBuilder sb, string url, string priority, string changeFreq)
    {
        sb.AppendLine("  <url>");
        sb.AppendLine($"    <loc>{url}</loc>");
        sb.AppendLine($"    <lastmod>{DateTime.UtcNow:yyyy-MM-dd}</lastmod>");
        sb.AppendLine($"    <changefreq>{changeFreq}</changefreq>");
        sb.AppendLine($"    <priority>{priority}</priority>");
        sb.AppendLine("  </url>");
    }
}
