import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Company } from '../types';
import { Search, ChevronRight, ArrowUpRight, ArrowDownRight } from './Icons';
import { API_BASE_URL } from '../constants';

interface Props {
  companies: Company[];
}

interface PriceData {
  price: number;
  change: number;
}

const CompaniesView: React.FC<Props> = ({ companies }) => {
  const navigate = useNavigate();
  const [search, setSearch] = useState('');
  const [selectedFilter, setSelectedFilter] = useState(0);
  const [priceData, setPriceData] = useState<Record<string, PriceData>>({});
  const [loadingPrices, setLoadingPrices] = useState(true);

  // Fetch all prices at once (like mobile app)
  useEffect(() => {
    const fetchAllPrices = async () => {
      setLoadingPrices(true);
      try {
        const response = await fetch(`${API_BASE_URL}/Prices`);
        if (response.ok) {
          const allPrices = await response.json();
          const priceMap: Record<string, PriceData> = {};

          allPrices.forEach((item: any) => {
            const ticker = item.ticker || '';
            const extra = item.extraElements || {};
            if (ticker) {
              priceMap[ticker] = {
                price: extra.Last ?? extra.last ?? 0,
                change: extra.DailyChangePercent ?? extra.dailyChangePercent ?? 0
              };
            }
          });

          setPriceData(priceMap);
        }
      } catch (error) {
        console.error("Failed to fetch prices:", error);
      } finally {
        setLoadingPrices(false);
      }
    };

    fetchAllPrices();
  }, []);

  // Filter companies
  const filteredCompanies = companies.filter(c => {
    // Search filter
    const matchesSearch = c.name.toLowerCase().includes(search.toLowerCase()) ||
      c.code.toLowerCase().includes(search.toLowerCase());

    if (!matchesSearch) return false;

    // Tab filters
    switch (selectedFilter) {
      case 1: // Yükselenler
        return (priceData[c.code]?.change ?? 0) > 0;
      case 2: // Düşenler
        return (priceData[c.code]?.change ?? 0) < 0;
      default:
        return true;
    }
  });

  return (
    <div className="pb-24 lg:pb-8 pt-4 px-4 min-h-screen">
      <div className="sticky top-14 lg:top-0 z-30 -mx-4 px-4 py-3 bg-market-bg/95 backdrop-blur-md border-b border-market-border mb-6">
        <div className="max-w-7xl mx-auto">
          <h1 className="text-2xl font-bold text-market-text mb-4">BIST Şirketleri</h1>

          {/* Search Bar */}
          <div className="relative mb-4">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <Search size={18} className="text-market-muted" />
            </div>
            <input
              type="text"
              placeholder="Hisse kodu veya şirket ara..."
              className="block w-full pl-10 pr-3 py-3 border border-market-border rounded-xl leading-5 bg-market-card text-market-text placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-market-accent focus:border-market-accent sm:text-sm transition-all shadow-sm"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>

          {/* Filter Tabs (like mobile app) */}
          <div className="flex space-x-2 overflow-x-auto no-scrollbar">
            {['Tümü', 'Yükselenler', 'Düşenler'].map((label, idx) => (
              <button
                key={idx}
                onClick={() => setSelectedFilter(idx)}
                className={`px-4 py-2 text-sm font-medium rounded-lg whitespace-nowrap transition-all ${selectedFilter === idx
                    ? 'bg-market-accent text-white shadow-md'
                    : 'text-market-muted hover:bg-market-card hover:text-market-text border border-market-border'
                  }`}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      </div>

      {/* Grid */}
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filteredCompanies.map((company) => {
          const price = priceData[company.code]?.price ?? 0;
          const change = priceData[company.code]?.change ?? 0;
          const isPositive = change > 0;
          const isNegative = change < 0;

          return (
            <div
              key={company.code}
              onClick={() => navigate(`/companies/${company.code}`)}
              className="flex items-center justify-between p-4 bg-market-card border border-market-border rounded-xl hover:border-market-accent/50 hover:shadow-md active:scale-[0.99] transition-all cursor-pointer group"
            >
              <div className="flex items-center space-x-4">
                <div className={`w-12 h-12 rounded-lg ${company.logoColor} flex items-center justify-center text-white font-bold text-sm shadow-md relative overflow-hidden`}>
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
                  <h3 className="text-market-text font-bold text-lg group-hover:text-market-accent transition-colors">{company.code}</h3>
                  <p className="text-market-muted text-sm truncate max-w-[150px]">{company.name}</p>
                </div>
              </div>

              {/* Price Display (like mobile app) */}
              <div className="flex items-center space-x-3">
                {!loadingPrices && price > 0 && (
                  <div className="text-right">
                    <div className="text-market-text font-bold text-base">
                      ₺{price.toFixed(2)}
                    </div>
                    <div className={`text-xs font-medium flex items-center justify-end ${isPositive ? 'text-green-500' : isNegative ? 'text-red-500' : 'text-market-muted'
                      }`}>
                      {isPositive ? <ArrowUpRight size={12} className="mr-0.5" /> :
                        isNegative ? <ArrowDownRight size={12} className="mr-0.5" /> : null}
                      {isPositive ? '+' : ''}{change.toFixed(2)}%
                    </div>
                  </div>
                )}
                <div className="text-market-muted group-hover:text-market-accent transition-colors">
                  <ChevronRight size={20} />
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {filteredCompanies.length === 0 && (
        <div className="text-center py-20 text-market-muted">
          <p className="text-lg">Sonuç bulunamadı.</p>
        </div>
      )}
    </div>
  );
};

export default CompaniesView;