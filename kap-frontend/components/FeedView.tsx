import React, { useMemo, useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Notification, FilterState, Company, PriceItem } from '../types';
import NotificationCard from './NotificationCard';
import { Calendar, X, Filter, Clock, ChevronRight, BellRing, TrendingUp, ArrowUp } from './Icons';
import { API_BASE_URL } from '../constants';

interface Props {
  notifications: Notification[];
  filter: FilterState;
  setFilter: React.Dispatch<React.SetStateAction<FilterState>>;
  companies: Company[];
  onLoadMore: () => void;
  hasMoreNews: boolean;
  isLoadingMore: boolean;
}

interface TickerItem {
  code: string;
  price: string;
  diff: string;
  change: string;
}

const FeedView: React.FC<Props> = ({ notifications, filter, setFilter, companies, onLoadMore, hasMoreNews, isLoadingMore }) => {
  const navigate = useNavigate();

  const [risingStocks, setRisingStocks] = useState<TickerItem[]>([]);
  const dateInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const fetchPrices = async () => {
      try {
        const response = await fetch(`${API_BASE_URL}/prices`);
        if (!response.ok) return;
        const data: PriceItem[] = await response.json();

        // Filter risers and map
        const risers = data
          .filter(item => (item.extraElements?.DailyChangePercent || 0) > 0)
          .map(item => {
            const percent = item.extraElements.DailyChangePercent || 0;
            const price = item.extraElements.Last || 0;
            const change = item.extraElements.DailyChange || 0;
            return {
              code: item.ticker,
              price: price.toFixed(2),
              diff: change > 0 ? `+${change.toFixed(2)}` : change.toFixed(2),
              change: `%${percent.toFixed(2)}`
            };
          });

        // Shuffle and take random 15
        const shuffled = risers.sort(() => 0.5 - Math.random());
        setRisingStocks(shuffled.slice(0, 15));
      } catch (e) {
        console.error("Failed to fetch prices:", e);
      }
    };

    fetchPrices();
    const interval = setInterval(fetchPrices, 60000); // Update every minute
    return () => clearInterval(interval);
  }, []);

  const filteredNotifications = useMemo(() => {
    return notifications.filter(n => {
      const matchDate = filter.date ? n.date === filter.date : true;
      const matchCompany = filter.companyCode ? n.companyCode === filter.companyCode : true;
      return matchDate && matchCompany;
    });
  }, [notifications, filter]);

  const activeCompanyName = companies.find(c => c.code === filter.companyCode)?.name;
  const isCompanyView = !!filter.companyCode;

  // Hero logic: Only show hero on main feed (no filters at all)
  const showHero = !filter.date && !isCompanyView && filteredNotifications.length > 0;
  const featuredNotification = showHero ? filteredNotifications[0] : null;
  const listNotifications = showHero ? filteredNotifications.slice(1) : filteredNotifications;

  // Duplicate stocks for infinite marquee effect
  const tickerItems = useMemo(() => [...risingStocks, ...risingStocks], [risingStocks]);

  return (
    <div className="pb-12 pt-6 min-h-screen">

      {/* Header / Filter Bar */}
      <div className="mb-8 px-4 max-w-7xl mx-auto">
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 border-b border-market-border pb-4">
          <div>
            <h1 className="text-3xl font-bold text-market-text tracking-tight mb-2">
              {isCompanyView ? activeCompanyName : 'KAP Haberleri'}
            </h1>
            <p className="text-market-muted text-sm">
              {isCompanyView
                ? `${filter.companyCode} hissesi için KAP bildirim akışı.`
                : 'BIST100 şirketlerinden son dakika KAP bildirimleri ve gelişmeler.'}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2">
            {/* Date Filter */}
            <div className="relative group" onClick={() => dateInputRef.current?.showPicker()}>
              <input
                ref={dateInputRef}
                type="date"
                className="absolute inset-0 opacity-0 w-full h-full cursor-pointer z-10"
                onChange={(e) => setFilter(prev => ({ ...prev, date: e.target.value || null }))}
              />
              <button
                className={`flex items-center px-4 py-2 rounded-md text-sm font-medium border transition-colors ${filter.date ? 'bg-market-accent text-white border-market-accent' : 'bg-market-card border-market-border text-market-text group-hover:bg-market-hover'}`}
              >
                <Calendar size={16} className="mr-2" />
                {filter.date ? filter.date : 'Tarih'}
              </button>
            </div>

            {/* Clear Filters Button (if active) */}
            {(filter.date || filter.companyCode) && (
              <button
                onClick={() => setFilter({ date: null, companyCode: null })}
                className="flex items-center px-4 py-2 rounded-md text-sm font-medium bg-red-50 text-red-600 border border-red-200 hover:bg-red-100 transition-colors dark:bg-red-900/20 dark:text-red-300 dark:border-red-900/50"
              >
                <X size={16} className="mr-1" />
                Temizle
              </button>
            )}
          </div>
        </div>

        {/* Active Company Filter Badge (Breadcrumb style) */}
        {filter.companyCode && (
          <div className="mt-4 flex items-center animate-fade-in">
            <button
              onClick={() => setFilter(prev => ({ ...prev, companyCode: null }))}
              className="text-sm text-market-muted hover:text-market-text flex items-center"
            >
              Haberler <ChevronRight size={14} className="mx-1" />
            </button>
            <div className="flex items-center bg-blue-50 border border-blue-200 px-3 py-1 rounded-md text-sm text-blue-700 dark:bg-blue-900/20 dark:border-blue-800 dark:text-blue-300 ml-2">
              <span className="font-bold mr-2">{filter.companyCode}</span>
              <button onClick={() => setFilter(prev => ({ ...prev, companyCode: null }))} className="hover:text-blue-900 dark:hover:text-blue-100">
                <X size={14} />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* Date Filter Heading */}
      {filter.date && !filter.companyCode && (
        <div className="px-4 max-w-7xl mx-auto mb-6">
          <h2 className="text-2xl font-bold text-market-text">
            {new Date(filter.date + 'T00:00:00').toLocaleDateString('tr-TR', {
              year: 'numeric',
              month: 'long',
              day: 'numeric'
            })} Tarihindeki Haberler:
          </h2>
        </div>
      )}

      {/* Hero Section (Only on main feed) */}
      {featuredNotification && (
        <section className="mb-8 animate-fade-in px-4 max-w-7xl mx-auto">
          <div
            className="group relative w-full h-[400px] md:h-[500px] rounded-2xl overflow-hidden cursor-pointer shadow-lg border border-market-border"
            onClick={() => navigate(`/news/${featuredNotification.id}`)}
          >
            <div className="absolute inset-0">
              <img
                src={featuredNotification.imageUrl}
                alt={featuredNotification.title}
                className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105"
              />
              <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/50 to-transparent" />

              {/* Company Logo Overlay */}
              <div className="absolute top-6 left-6 w-24 h-24 flex items-center justify-center">
                <img
                  src={`http://localhost:5296/logos/${featuredNotification.companyCode}.svg`}
                  alt={featuredNotification.companyCode}
                  className="w-full h-full object-contain drop-shadow-lg"
                  onError={(e) => {
                    e.currentTarget.style.display = 'none';
                    const parent = e.currentTarget.parentElement;
                    if (parent) {
                      parent.innerHTML = `<div class="bg-white/90 backdrop-blur-sm px-3 py-2 rounded-lg shadow-lg"><span class="text-sm font-bold text-gray-700">${featuredNotification.companyCode}</span></div>`;
                    }
                  }}
                />
              </div>
            </div>

            <div className="absolute bottom-0 left-0 right-0 p-6 md:p-10">
              <div className="flex items-center space-x-3 mb-3">
                <span className="bg-market-accent text-white px-3 py-1 rounded text-xs font-bold uppercase tracking-wider shadow-sm">
                  Günün Son Haberi
                </span>
                {featuredNotification.isImportant && (
                  <span className="bg-red-600 text-white px-3 py-1 rounded text-xs font-bold uppercase tracking-wider flex items-center animate-pulse">
                    <BellRing size={12} className="mr-1" /> Kritik
                  </span>
                )}
              </div>

              <h2 className="text-3xl md:text-5xl font-bold text-white mb-3 leading-tight font-serif drop-shadow-md">
                {featuredNotification.title}
              </h2>

              <p className="text-gray-300 text-base md:text-lg line-clamp-2 max-w-3xl mb-4 drop-shadow-sm">
                {featuredNotification.summary}
              </p>

              <div className="flex items-center text-gray-400 text-sm font-medium">
                <span className="text-white border-r border-gray-600 pr-3 mr-3">{featuredNotification.companyName}</span>
                <Clock size={16} className="mr-1.5" />
                {featuredNotification.timestamp}
                <span className="mx-2">•</span>
                {featuredNotification.date}
              </div>
            </div>
          </div>
        </section>
      )}

      {/* Continuous Ticker (Marquee) */}
      {showHero && (
        <section className="mb-10 w-full bg-market-card border-y border-market-border overflow-hidden relative shadow-sm">
          {/* Label Overlay - optional for context, but classic tickers usually just flow */}
          <div className="absolute left-0 top-0 bottom-0 z-10 bg-market-accent text-white px-3 flex items-center font-bold text-xs uppercase tracking-wider shadow-md">
            <TrendingUp size={16} className="mr-2" />
            Yükselenler
          </div>

          <div className="flex animate-marquee hover:[animation-play-state:paused]">
            {tickerItems.map((stock, idx) => (
              <div key={`${stock.code}-${idx}`} className="flex-shrink-0 flex items-center h-12 px-6 border-r border-market-border/40 select-none whitespace-nowrap">
                <span className="font-bold text-market-text mr-3 text-sm">{stock.code}</span>
                <span className="text-market-text mr-3 font-mono text-sm">{stock.price}</span>
                <div className="flex items-center text-market-green text-xs font-bold bg-green-500/10 px-1.5 py-0.5 rounded">
                  <ArrowUp size={12} className="mr-1" strokeWidth={3} />
                  <span className="mr-1">{stock.change}</span>
                  <span className="opacity-75">({stock.diff})</span>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Feed Content */}
      <div className={`px-4 max-w-7xl mx-auto ${isCompanyView ? "max-w-2xl" : ""}`}>
        {listNotifications.length > 0 ? (
          <div className={isCompanyView ? "flex flex-col space-y-4" : "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"}>
            {listNotifications.map(notification => (
              <NotificationCard
                key={notification.id}
                notification={notification}
                onClick={() => navigate(`/news/${notification.id}`)}
                variant={isCompanyView ? 'list' : 'grid'}
              />
            ))}
          </div>
        ) : (
          <div className="text-center py-32 border border-dashed border-market-border rounded-xl bg-market-card/50">
            <div className="inline-flex p-4 rounded-full bg-market-bg mb-4">
              <Filter size={32} className="text-market-muted" />
            </div>
            <h3 className="text-lg font-bold text-market-text">Bildirim Bulunamadı</h3>
            <p className="text-market-muted text-sm mt-1 max-w-xs mx-auto">
              Seçtiğiniz tarih veya şirket kriterlerine uygun kayıt bulunmuyor.
            </p>
            <button
              onClick={() => setFilter({ date: null, companyCode: null })}
              className="mt-6 px-6 py-2 bg-market-text text-market-bg rounded hover:opacity-90 transition-opacity text-sm font-medium"
            >
              Filtreleri Sıfırla
            </button>
          </div>
        )}

        {/* Loader */}
        {listNotifications.length > 0 && hasMoreNews && (
          <div className="py-12 flex justify-center">
            <button
              onClick={onLoadMore}
              disabled={isLoadingMore}
              className="text-sm font-medium text-market-muted hover:text-market-text border border-market-border px-6 py-2 rounded-full hover:bg-market-card transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoadingMore ? 'Yükleniyor...' : 'Daha Fazla Göster'}
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default FeedView;