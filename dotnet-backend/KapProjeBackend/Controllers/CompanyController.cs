using KapProjeBackend.Models;
using KapProjeBackend.Services;
using Microsoft.AspNetCore.Mvc;

namespace KapProjeBackend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CompanyController : ControllerBase
{
    private readonly FinancialsService _financialsService;

    public CompanyController(FinancialsService financialsService)
    {
        _financialsService = financialsService;
    }

    [HttpGet("{symbol}")]
    public async Task<ActionResult<CompanyDetailsDto>> GetCompanyDetails(string symbol)
    {
        if (string.IsNullOrWhiteSpace(symbol))
        {
            return BadRequest("Symbol cannot be empty.");
        }

        var details = await _financialsService.GetCompanyDetailsAsync(symbol);
        return Ok(details);
    }
}
