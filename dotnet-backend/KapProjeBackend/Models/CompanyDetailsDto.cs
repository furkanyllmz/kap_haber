namespace KapProjeBackend.Models;

public class CompanyDetailsDto
{
    public string Symbol { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public Dictionary<string, object> Financials { get; set; } = new();
}
