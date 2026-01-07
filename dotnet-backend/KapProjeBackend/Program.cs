using Microsoft.EntityFrameworkCore;
using KapProjeBackend.Data;
using KapProjeBackend.Models;
using KapProjeBackend.Services;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll",
        builder =>
        {
            builder.AllowAnyOrigin()
                   .AllowAnyMethod()
                   .AllowAnyHeader();
        });
});

builder.Services.AddControllers();
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlite(builder.Configuration.GetConnectionString("DefaultConnection")));

// MongoDB configuration
builder.Services.Configure<MongoDbSettings>(
    builder.Configuration.GetSection("MongoDb"));
builder.Services.AddSingleton<NewsService>();
builder.Services.AddSingleton<PriceService>();
builder.Services.AddHttpClient<ChartService>();
builder.Services.AddSingleton<ChartService>();

// Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new() { Title = "KAP News API", Version = "v1" });
});

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => c.SwaggerEndpoint("/swagger/v1/swagger.json", "KAP News API v1"));
}

app.UseHttpsRedirection();
app.UseStaticFiles(); // Enable static files (logos)
app.UseCors("AllowAll"); // Enable CORS

app.MapControllers();

app.Run();
