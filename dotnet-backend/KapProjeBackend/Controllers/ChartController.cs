using Microsoft.AspNetCore.Mvc;
using KapProjeBackend.Services;
using KapProjeBackend.Models;

namespace KapProjeBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ChartController : ControllerBase
{
    private readonly ChartService _chartService;

    public ChartController(ChartService chartService)
    {
        _chartService = chartService;
    }

    /// <summary>
    /// Get stock chart data
    /// GET /api/chart/ticker?symbol=ASELS&time=3A
    /// </summary>
    [HttpGet("ticker")]
    public async Task<ActionResult<List<ChartData>>> GetChart(
        [FromQuery] string symbol, 
        [FromQuery] string time)
    {
        if (string.IsNullOrEmpty(symbol) || string.IsNullOrEmpty(time))
        {
            return BadRequest("symbol and time parameters are required");
        }

        var data = await _chartService.GetChartDataAsync(symbol, time);
        return Ok(data);
    }
}
