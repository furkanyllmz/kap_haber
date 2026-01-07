using Microsoft.AspNetCore.Mvc;
using KapProjeBackend.Services;
using KapProjeBackend.Models;

namespace KapProjeBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class NewsController : ControllerBase
{
    private readonly NewsService _newsService;

    public NewsController(NewsService newsService)
    {
        _newsService = newsService;
    }

    /// <summary>
    /// Tüm haberleri getir (sayfalı)
    /// GET /api/news?page=1&pageSize=20
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<List<NewsItem>>> GetAll(
        [FromQuery] int page = 1, 
        [FromQuery] int pageSize = 20)
    {
        var news = await _newsService.GetAllAsync(page, pageSize);
        var total = await _newsService.GetCountAsync();
        
        Response.Headers.Append("X-Total-Count", total.ToString());
        Response.Headers.Append("X-Page", page.ToString());
        Response.Headers.Append("X-Page-Size", pageSize.ToString());
        
        return Ok(news);
    }

    /// <summary>
    /// Son N haberi getir
    /// GET /api/news/latest?count=10
    /// </summary>
    [HttpGet("latest")]
    public async Task<ActionResult<List<NewsItem>>> GetLatest([FromQuery] int count = 10)
    {
        var news = await _newsService.GetLatestAsync(count);
        return Ok(news);
    }

    /// <summary>
    /// Bugünün haberlerini getir
    /// GET /api/news/today
    /// </summary>
    [HttpGet("today")]
    public async Task<ActionResult<List<NewsItem>>> GetToday()
    {
        var news = await _newsService.GetTodayAsync();
        return Ok(news);
    }

    /// <summary>
    /// Belirli bir tarihteki haberler
    /// GET /api/news/date/2026-01-06
    /// </summary>
    [HttpGet("date/{date}")]
    public async Task<ActionResult<List<NewsItem>>> GetByDate(string date)
    {
        // Tarih formatı kontrolü (YYYY-MM-DD)
        if (!System.Text.RegularExpressions.Regex.IsMatch(date, @"^\d{4}-\d{2}-\d{2}$"))
        {
            return BadRequest("Tarih formatı YYYY-MM-DD olmalı");
        }
        
        var news = await _newsService.GetByDateAsync(date);
        return Ok(news);
    }

    /// <summary>
    /// Tarih aralığındaki haberler
    /// GET /api/news/range?from=2026-01-01&to=2026-01-06
    /// </summary>
    [HttpGet("range")]
    public async Task<ActionResult<List<NewsItem>>> GetByDateRange(
        [FromQuery] string from, 
        [FromQuery] string to)
    {
        if (string.IsNullOrEmpty(from) || string.IsNullOrEmpty(to))
        {
            return BadRequest("'from' ve 'to' parametreleri gerekli");
        }
        
        var news = await _newsService.GetByDateRangeAsync(from, to);
        return Ok(news);
    }

    /// <summary>
    /// Belirli hissenin haberleri
    /// GET /api/news/ticker/ASELS?page=1&pageSize=20
    /// </summary>
    [HttpGet("ticker/{ticker}")]
    public async Task<ActionResult<List<NewsItem>>> GetByTicker(
        string ticker, 
        [FromQuery] int page = 1, 
        [FromQuery] int pageSize = 20)
    {
        var news = await _newsService.GetByTickerAsync(ticker, page, pageSize);
        var total = await _newsService.GetCountByTickerAsync(ticker);
        
        Response.Headers.Append("X-Total-Count", total.ToString());
        Response.Headers.Append("X-Ticker", ticker.ToUpper());
        
        return Ok(news);
    }

    /// <summary>
    /// Toplam haber sayısı
    /// GET /api/news/count
    /// </summary>
    [HttpGet("count")]
    public async Task<ActionResult<object>> GetCount([FromQuery] string? ticker = null)
    {
        if (!string.IsNullOrEmpty(ticker))
        {
            var tickerCount = await _newsService.GetCountByTickerAsync(ticker);
            return Ok(new { ticker = ticker.ToUpper(), count = tickerCount });
        }
        
        var totalCount = await _newsService.GetCountAsync();
        return Ok(new { count = totalCount });
    }

    /// <summary>
    /// ID'ye göre haber getir
    /// GET /api/news/{id}
    /// </summary>
    [HttpGet("{id}")]
    public async Task<ActionResult<NewsItem>> GetById(string id)
    {
        var news = await _newsService.GetByIdAsync(id);
        if (news == null)
        {
            return NotFound(new { message = "Haber bulunamadı" });
        }
        return Ok(news);
    }
}
