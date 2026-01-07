using KapProjeBackend.Models;
using KapProjeBackend.Services;
using Microsoft.AspNetCore.Mvc;

namespace KapProjeBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PricesController : ControllerBase
{
    private readonly PriceService _priceService;

    public PricesController(PriceService priceService)
    {
        _priceService = priceService;
    }

    [HttpGet("ticker/{ticker}")]
    public async Task<ActionResult<PriceItem>> GetByTicker(string ticker)
    {
        var price = await _priceService.GetByTickerAsync(ticker);
        if (price == null)
        {
            return NotFound();
        }
        return Ok(price);
    }
    
    [HttpGet]
    public async Task<ActionResult<List<PriceItem>>> GetAll()
    {
        var prices = await _priceService.GetAllAsync();
        return Ok(prices);
    }
}
