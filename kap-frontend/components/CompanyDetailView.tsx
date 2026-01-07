import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Company, Notification } from '../types';
import { ChevronLeft, ArrowUpRight, ArrowDownRight, Clock, Calendar } from './Icons';
import { API_BASE_URL, LOGO_BASE_URL } from '../constants';
import {
    AreaChart,
    Area,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    ResponsiveContainer
} from 'recharts';

interface Props {
    companies: Company[];
}

type TimeFrame = '1G' | '1H' | '1A' | '3A' | '1Y' | '5Y';

interface StockDataPoint {
    date: string; // or timestamp
    price: number;
}

const STAT_LABELS: Record<string, string> = {
    market_cap: 'Piyasa Değeri',
    net_profit: 'Net Kâr',
    revenue: 'Satış Gelirleri',
    free_float_rate: 'Halka Açıklık Oranı',
    symbol: 'Hisse Kodu',
    fetched_at: 'Veri Tarihi',
    fetched_using: 'Veri Kaynağı' // Usually hidden
};

const IGNORED_KEYS = ['fetched_at', 'fetched_using', 'symbol'];

const formatValue = (key: string, value: any) => {
    if (key === 'market_cap' || key === 'net_profit' || key === 'revenue') {
        const str = String(value);
        return str.includes('mnTL') ? str : `${str} TL`; // Simple heuristic
    }
    if (key === 'free_float_rate') {
        const str = String(value);
        return str.includes('%') ? str : `%${str}`;
    }
    return value;
};

const CompanyDetailView: React.FC<Props> = ({ companies }) => {
    const { symbol } = useParams<{ symbol: string }>();
    const navigate = useNavigate();
    const companyCode = symbol || '';

    const company = companies.find(c => c.code === companyCode) || {
        code: companyCode,
        name: companyCode,
        logoColor: 'bg-gray-500'
    } as Company;

    const [timeframe, setTimeframe] = useState<TimeFrame>('3A');
    const [chartData, setChartData] = useState<StockDataPoint[]>([]);
    const [news, setNews] = useState<Notification[]>([]);
    const [loadingChart, setLoadingChart] = useState(false);
    const [loadingNews, setLoadingNews] = useState(false);
    const [currentPrice, setCurrentPrice] = useState<number | null>(null);
    const [percentChange, setPercentChange] = useState<number | null>(null);
    const [companyDetails, setCompanyDetails] = useState<{ name: string, financials: any } | null>(null);

    // Fetch Company Details (Name + Financials)
    useEffect(() => {
        if (!companyCode) return;
        const fetchDetails = async () => {
            try {
                // Now using .NET Backend via API_BASE_URL
                const res = await fetch(`${API_BASE_URL}/company/${companyCode}`);
                if (res.ok) {
                    const data = await res.json();
                    setCompanyDetails(data);
                }
            } catch (err) {
                console.error("Failed to fetch company details:", err);
            }
        };
        fetchDetails();
    }, [companyCode]);

    // Fetch Stock Data
    useEffect(() => {
        if (!companyCode) return;
        const fetchStockData = async () => {
            setLoadingChart(true);
            try {
                // Backend endpoint: /api/chart/ticker?symbol=ASELS&time=3A
                const response = await fetch(`${API_BASE_URL}/chart/ticker?symbol=${companyCode}&time=${timeframe}`);
                if (!response.ok) throw new Error('Failed to fetch stock data');

                const data = await response.json();

                // Backend returns List<ChartData> { date: string, price: number }
                const mappedData = data.map((item: any) => ({
                    date: item.date,
                    price: item.price
                }));

                setChartData(mappedData);

                if (mappedData.length > 0) {
                    const lastPrice = mappedData[mappedData.length - 1].price;
                    const firstPrice = mappedData[0].price;
                    setCurrentPrice(lastPrice);
                    setPercentChange(((lastPrice - firstPrice) / firstPrice) * 100);
                }

            } catch (error) {
                console.error("Error fetching stock data:", error);
            } finally {
                setLoadingChart(false);
            }
        };

        fetchStockData();
    }, [companyCode, timeframe]);

    // Fetch News for Company
    useEffect(() => {
        if (!companyCode) return;
        const fetchNews = async () => {
            setLoadingNews(true);
            try {
                const response = await fetch(`${API_BASE_URL}/news/ticker/${companyCode}`);
                if (!response.ok) throw new Error('Failed to fetch company news');

                const data = await response.json();
                const mappedNotifications: Notification[] = data.map((item: any) => ({
                    id: item.id || Math.random().toString(),
                    companyCode: item.primaryTicker || companyCode,
                    companyName: item.primaryTicker || companyCode,
                    title: item.headline || 'Başlıksız Bildirim',
                    summary: item.seo?.metaDescription || item.summary || item.tweet?.text || '',
                    imageUrl: item.imageUrl || '/banners/diğer.jpg',
                    date: item.publishedAt?.date || new Date().toISOString().split('T')[0],
                    timestamp: item.publishedAt?.time || '',
                    kapUrl: item.url || '#',
                    tags: item.tweet?.hashtags || [],
                    isImportant: (item.newsworthiness || 0) > 0.6
                }));

                setNews(mappedNotifications);
            } catch (error) {
                console.error("Error fetching company news:", error);
                setNews([]);
            } finally {
                setLoadingNews(false);
            }
        };

        fetchNews();
    }, [companyCode]);

    const isPositive = (percentChange || 0) >= 0;

    if (!symbol) return null;

    return (
        <div className="pb-24 lg:pb-8 bg-market-bg min-h-screen">
            {/* Header */}
            <div className="sticky top-14 lg:top-0 z-30 px-4 py-3 bg-market-bg/95 backdrop-blur-md border-b border-market-border">
                <div className="max-w-4xl mx-auto flex items-center space-x-4">
                    <button
                        onClick={() => navigate('/companies')}
                        className="p-2 -ml-2 text-market-muted hover:text-market-text hover:bg-market-card rounded-full transition-colors"
                    >
                        <ChevronLeft size={24} />
                    </button>

                    <div className={`w-10 h-10 rounded-lg ${company.logoColor} flex items-center justify-center text-white font-bold text-xs shadow-sm relative overflow-hidden`}>
                        <span className="z-0">{company.code.substring(0, 2)}</span>
                        {company.logoUrl && (
                            <img
                                src={company.logoUrl}
                                alt={company.code}
                                className="absolute inset-0 w-full h-full object-contain bg-white"
                                onError={(e) => { e.currentTarget.style.display = 'none' }}
                            />
                        )}
                    </div>

                    <div>
                        <h1 className="text-xl font-bold text-market-text leading-none">{company.code}</h1>
                        <p className="text-xs text-market-muted truncate max-w-[200px]">
                            {companyDetails?.name || company.name}
                        </p>
                    </div>

                    <div className="flex-1" />

                    {/* Price Display */}
                    {currentPrice && (
                        <div className="text-right">
                            <div className="text-lg font-bold text-market-text">
                                ₺{currentPrice.toFixed(2)}
                            </div>
                            <div className={`text-xs font-medium flex items-center justify-end ${isPositive ? 'text-green-500' : 'text-red-500'}`}>
                                {isPositive ? <ArrowUpRight size={14} className="mr-0.5" /> : <ArrowDownRight size={14} className="mr-0.5" />}
                                {Math.abs(percentChange || 0).toFixed(2)}%
                                <span className="text-market-muted ml-1 hidden sm:inline">({timeframe})</span>
                            </div>
                        </div>
                    )}
                </div>
            </div>


            <div className="max-w-4xl mx-auto px-4 py-6 space-y-6">

                {/* Financials Section */}
                {companyDetails?.financials && Object.keys(companyDetails.financials).length > 0 && (
                    <div className="bg-market-card rounded-2xl p-5 border border-market-border shadow-sm mb-6">
                        <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
                            {Object.entries(companyDetails.financials).map(([key, value]) => {
                                if (!value || IGNORED_KEYS.includes(key)) return null;
                                const label = STAT_LABELS[key] || key;
                                const displayValue = formatValue(key, value);

                                return (
                                    <div key={key} className="flex flex-col">
                                        <span className="text-xs text-market-muted uppercase tracking-wider font-semibold mb-1 opacity-70">
                                            {label}
                                        </span>
                                        <span className="text-lg md:text-xl font-bold text-market-text tracking-tight">
                                            {String(displayValue)}
                                        </span>
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                )}

                {/* Chart Section */}
                <div className="bg-market-card rounded-2xl p-4 border border-market-border shadow-sm">
                    {/* Timeframe Selector */}
                    <div className="flex items-center justify-between mb-4 overflow-x-auto no-scrollbar">
                        <div className="flex space-x-2">
                            {(['1G', '1H', '1A', '3A', '1Y', '5Y'] as TimeFrame[]).map((tf) => (
                                <button
                                    key={tf}
                                    onClick={() => setTimeframe(tf)}
                                    className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-all whitespace-nowrap ${timeframe === tf
                                        ? 'bg-market-accent text-white shadow-md'
                                        : 'text-market-muted hover:bg-market-bg hover:text-market-text'
                                        }`}
                                >
                                    {tf}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Chart Area */}
                    <div className="h-[300px] w-full">
                        {loadingChart ? (
                            <div className="h-full flex items-center justify-center text-market-muted animate-pulse">
                                Grafik Yükleniyor...
                            </div>
                        ) : chartData.length > 0 ? (
                            <ResponsiveContainer width="100%" height="100%">
                                <AreaChart data={chartData}>
                                    <defs>
                                        <linearGradient id="colorPrice" x1="0" y1="0" x2="0" y2="1">
                                            <stop offset="5%" stopColor={isPositive ? "#10b981" : "#ef4444"} stopOpacity={0.3} />
                                            <stop offset="95%" stopColor={isPositive ? "#10b981" : "#ef4444"} stopOpacity={0} />
                                        </linearGradient>
                                    </defs>
                                    <Tooltip
                                        contentStyle={{
                                            backgroundColor: 'rgba(30, 41, 59, 0.9)',
                                            borderColor: '#334155',
                                            color: '#f1f5f9',
                                            borderRadius: '8px',
                                            fontSize: '12px'
                                        }}
                                        itemStyle={{ color: '#fff' }}
                                        labelStyle={{ color: '#94a3b8', marginBottom: '4px' }}
                                        formatter={(value: any) => [`₺${Number(value).toFixed(2)}`, 'Fiyat']}
                                        labelFormatter={(label) => label} // You might want to format date here
                                    />
                                    <Area
                                        type="monotone"
                                        dataKey="price"
                                        stroke={isPositive ? "#10b981" : "#ef4444"}
                                        strokeWidth={2}
                                        fillOpacity={1}
                                        fill="url(#colorPrice)"
                                    />
                                    {/* Hidden Axes for cleaner look, or minimal axes */}
                                    <YAxis domain={['auto', 'auto']} hide={true} />
                                    <XAxis dataKey="date" hide={true} />
                                </AreaChart>
                            </ResponsiveContainer>
                        ) : (
                            <div className="h-full flex items-center justify-center text-market-muted">
                                Veri bulunamadı.
                            </div>
                        )}
                    </div>
                </div>

                {/* News Section */}
                <div>
                    <h2 className="text-lg font-bold text-market-text mb-4 px-1">Şirket Haberleri</h2>
                    <div className="space-y-4">
                        {loadingNews ? (
                            <div className="flex flex-col space-y-4">
                                {[1, 2, 3].map(i => (
                                    <div key={i} className="h-32 bg-market-card rounded-2xl animate-pulse border border-market-border"></div>
                                ))}
                            </div>
                        ) : news.length > 0 ? (
                            news.map((item) => (
                                <div
                                    key={item.id}
                                    onClick={() => navigate(`/news/${item.id}`)}
                                    className="group bg-market-card border border-market-border p-4 rounded-2xl shadow-sm hover:shadow-md hover:border-market-accent/50 transition-all cursor-pointer active:scale-[0.99]"
                                >
                                    <div className="flex justify-between items-start mb-2">
                                        <div className="flex items-center space-x-2">
                                            <div className={`px-2.5 py-1 rounded-full text-xs font-medium bg-market-bg text-market-text border border-market-border group-hover:border-market-accent/30 transition-colors`}>
                                                {item.companyCode}
                                            </div>
                                            <span className="text-xs text-market-muted flex items-center">
                                                <Clock size={12} className="mr-1" />
                                                {item.timestamp}
                                            </span>
                                            <span className="text-xs text-market-muted flex items-center">
                                                <Calendar size={12} className="mr-1" />
                                                {item.date}
                                            </span>
                                        </div>
                                        {item.isImportant && (
                                            <span className="flex h-2 w-2 relative">
                                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75"></span>
                                                <span className="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
                                            </span>
                                        )}
                                    </div>

                                    <h3 className="text-market-text font-bold text-base mb-2 group-hover:text-market-accent transition-colors line-clamp-2">
                                        {item.title}
                                    </h3>

                                    <p className="text-market-muted text-sm line-clamp-3 mb-3">
                                        {item.summary}
                                    </p>
                                </div>
                            ))
                        ) : (
                            <div className="text-center py-10 text-market-muted bg-market-card rounded-2xl border border-market-border">
                                Bu şirket için henüz haber yok.
                            </div>
                        )}
                    </div>
                </div>

            </div>
        </div >
    );
};

export default CompanyDetailView;

