import React, { useState, useEffect } from 'react';
import { ViewState, FilterState, Notification, Company, PriceItem } from './types';
import { API_BASE_URL, LOGO_BASE_URL, MOCK_NOTIFICATIONS } from './constants';
import Layout from './components/Layout';
import FeedView from './components/FeedView';
import CompaniesView from './components/CompaniesView';
import AboutView from './components/AboutView';
import NotificationDetail from './components/NotificationDetail';
import CompanyDetailView from './components/CompanyDetailView';
import AdminLogin from './components/AdminLogin';
import AdminPanel from './components/AdminPanel';

const LOGO_COLORS = [
  'bg-red-600', 'bg-blue-600', 'bg-green-600', 'bg-slate-500',
  'bg-purple-600', 'bg-yellow-600', 'bg-indigo-600', 'bg-pink-600'
];

const App: React.FC = () => {
  const [currentView, setCurrentView] = useState<ViewState>('feed');
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [filter, setFilter] = useState<FilterState>({ date: null, companyCode: null });
  const [selectedNotificationId, setSelectedNotificationId] = useState<string | null>(null);
  const [selectedCompanyCode, setSelectedCompanyCode] = useState<string | null>(null);
  const [isAdminAuthenticated, setIsAdminAuthenticated] = useState(false);

  // Theme management
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');

  useEffect(() => {
    // Check local storage or system preference
    const savedTheme = localStorage.getItem('theme') as 'dark' | 'light' | null;
    if (savedTheme) {
      setTheme(savedTheme);
    } else if (window.matchMedia('(prefers-color-scheme: light)').matches) {
      setTheme('light');
    }
  }, []);

  useEffect(() => {
    const root = document.documentElement;
    if (theme === 'dark') {
      root.classList.add('dark');
    } else {
      root.classList.remove('dark');
    }
    localStorage.setItem('theme', theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => prev === 'dark' ? 'light' : 'dark');
  };

  // Fetch Companies
  useEffect(() => {
    const fetchCompanies = async () => {
      try {
        const response = await fetch(`${API_BASE_URL}/prices`);
        if (!response.ok) throw new Error('Failed to fetch companies');

        const data: PriceItem[] = await response.json();
        const mappedCompanies: Company[] = data.map((item, index) => ({
          code: item.ticker,
          name: item.ticker, // API doesn't allow full name yet, using ticker
          logoColor: LOGO_COLORS[index % LOGO_COLORS.length],
          logoUrl: `${LOGO_BASE_URL}/${item.ticker}.svg`
        })).sort((a, b) => a.code.localeCompare(b.code));

        setCompanies(mappedCompanies);
      } catch (error) {
        console.error("Error fetching companies:", error);
      }
    };
    fetchCompanies();
  }, []);

  // Fetch News (Filtered or Latest)
  useEffect(() => {
    const fetchNews = async () => {
      try {
        let url = `${API_BASE_URL}/news/latest?count=50`;

        if (filter.date) {
          // Fetch news by specific date
          url = `${API_BASE_URL}/news/date/${filter.date}`;
        } else if (filter.companyCode) {
          // Fetch news by ticker
          url = `${API_BASE_URL}/news/ticker/${filter.companyCode}`;
        }

        const response = await fetch(url);
        if (!response.ok) {
          throw new Error('Network response was not ok');
        }
        const data = await response.json();

        const mappedNotifications: Notification[] = data.map((item: any) => ({
          id: item.id || Math.random().toString(),
          companyCode: item.primaryTicker || 'UNKNOWN',
          companyName: item.primaryTicker || 'Unknown Company',
          title: item.headline || 'Başlıksız Bildirim',
          summary: item.seo?.metaDescription || item.summary || item.tweet?.text || '',
          imageUrl: item.imageUrl || '/banners/diğer.jpg',
          date: item.publishedAt?.date || new Date().toISOString().split('T')[0],
          timestamp: item.publishedAt?.time || '',
          kapUrl: item.url || '#',
          tags: item.tweet?.hashtags || [],
          isImportant: (item.newsworthiness || 0) > 0.6
        }));

        setNotifications(mappedNotifications);
      } catch (error) {
        console.error("Failed to fetch news:", error);
        // Only use mock if no data at all and not filtering (to avoid confusing empty filter results with broken api)
        if (!filter.companyCode && !filter.date && notifications.length === 0) {
          setNotifications(MOCK_NOTIFICATIONS);
        } else if (filter.companyCode || filter.date) {
          setNotifications([]); // Clear list if specific filter fails (likely no news)
        }
      }
    };

    fetchNews();
  }, [filter.companyCode, filter.date]);

  // Handlers
  const handleCompanySelect = (code: string) => {
    setSelectedCompanyCode(code);
    setCurrentView('companyDetail');
  };

  const handleBackToCompanies = () => {
    setSelectedCompanyCode(null);
    setCurrentView('companies');
  };

  const handleNotificationClick = (id: string) => {
    setSelectedNotificationId(id);
    setCurrentView('detail');
    window.scrollTo(0, 0);
  };

  const handleBackToFeed = () => {
    setSelectedNotificationId(null);
    setCurrentView('feed');
  };

  const renderContent = () => {
    switch (currentView) {
      case 'feed':
        return (
          <FeedView
            notifications={notifications}
            filter={filter}
            setFilter={setFilter}
            companies={companies}
            onNotificationClick={handleNotificationClick}
          />
        );
      case 'companies':
        return (
          <CompaniesView
            companies={companies}
            onSelectCompany={handleCompanySelect}
          />
        );
      case 'companyDetail':
        if (!selectedCompanyCode) return <CompaniesView companies={companies} onSelectCompany={handleCompanySelect} />;
        return (
          <CompanyDetailView
            companyCode={selectedCompanyCode}
            companies={companies}
            onBack={handleBackToCompanies}
            onNotificationClick={handleNotificationClick}
          />
        );
      case 'about':
        return <AboutView onStart={() => setCurrentView('feed')} />;
      case 'detail':
        const selectedNotif = notifications.find(n => n.id === selectedNotificationId);
        if (!selectedNotif) return <FeedView notifications={notifications} filter={filter} setFilter={setFilter} companies={companies} onNotificationClick={handleNotificationClick} />;
        return (
          <NotificationDetail
            notification={selectedNotif}
            onBack={handleBackToFeed}
            recentNotifications={notifications}
            onSelectRelated={handleNotificationClick}
          />
        );
      case 'admin':
        if (!isAdminAuthenticated) {
          return <AdminLogin onLogin={(success) => setIsAdminAuthenticated(success)} />;
        }
        return <AdminPanel />;
      default:
        return null;
    }
  };

  return (
    <Layout
      currentView={currentView}
      setView={setCurrentView}
      theme={theme}
      toggleTheme={toggleTheme}
    >
      {renderContent()}
    </Layout>
  );
};

export default App;