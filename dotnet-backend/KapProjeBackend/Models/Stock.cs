namespace KapProjeBackend.Models
{
    public class Stock
    {
        public string Symbol { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public decimal LastPrice { get; set; }
    }
}
