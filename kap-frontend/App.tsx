import React, { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { Notification, Company, PriceItem, FilterState } from './types';
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

const AppContent: React.FC<{
  theme: 'dark' | 'light';
  toggleTheme: () => void;
  companies: Company[];
  notifications: Notification[];
  setNotifications: React.Dispatch<React.SetStateAction<Notification[]>>;
  filter: FilterState;
  setFilter: React.Dispatch<React.SetStateAction<FilterState>>;
  isAdminAuthenticated: boolean;
  setIsAdminAuthenticated: React.Dispatch<React.SetStateAction<boolean>>;
  onLoadMore: () => void;
  hasMoreNews: boolean;
  isLoadingMore: boolean;
}> = ({ theme, toggleTheme, companies, notifications, setNotifications, filter, setFilter, isAdminAuthenticated, setIsAdminAuthenticated, onLoadMore, hasMoreNews, isLoadingMore }) => {

  // We can use useLocation here if needed for Layout props, 
  // but Layout can also use useLocation internally.

  return (
    <Layout theme={theme} toggleTheme={toggleTheme}>
      <Routes>
        <Route path="/" element={
          <FeedView
            notifications={notifications}
            filter={filter}
            setFilter={setFilter}
            companies={companies}
            onLoadMore={onLoadMore}
            hasMoreNews={hasMoreNews}
            isLoadingMore={isLoadingMore}
          />
        } />
        <Route path="/news/:id" element={
          <NotificationDetail recentNotifications={notifications} />
        } />
        <Route path="/companies" element={
          <CompaniesView companies={companies} />
        } />
        <Route path="/companies/:symbol" element={
          <CompanyDetailView companies={companies} />
        } />
        <Route path="/about" element={<AboutView />} />
        <Route path="/admin" element={
          isAdminAuthenticated ? <AdminPanel /> : <AdminLogin onLogin={(success) => setIsAdminAuthenticated(success)} />
        } />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Layout>
  );
};

const App: React.FC = () => {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [filter, setFilter] = useState<FilterState>({ date: null, companyCode: null });
  const [isAdminAuthenticated, setIsAdminAuthenticated] = useState(false);
  const [currentPage, setCurrentPage] = useState(1);
  const [hasMoreNews, setHasMoreNews] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  // Theme management
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');

  useEffect(() => {
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
          name: item.ticker,
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

  // Fetch News (Global fetch for Feed)
  // Note: Optimally FeedView should fetch its own news or we keep it here to share state with Detail view if finding from list.
  useEffect(() => {
    const fetchNews = async (page: number = 1, append: boolean = false) => {
      try {
        if (!append) {
          setIsLoadingMore(false);
        }

        let url = `${API_BASE_URL}/news?page=${page}&pageSize=50`;

        if (filter.date) {
          url = `${API_BASE_URL}/news/date/${filter.date}`;
        } else if (filter.companyCode) {
          url = `${API_BASE_URL}/news/ticker/${filter.companyCode}?page=${page}&pageSize=50`;
        }

        const response = await fetch(url);
        if (!response.ok) throw new Error('Network response was not ok');
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

        // Check if there are more news to load
        setHasMoreNews(mappedNotifications.length === 50);

        if (append) {
          setNotifications(prev => [...prev, ...mappedNotifications]);
          setIsLoadingMore(false);
        } else {
          setNotifications(mappedNotifications);
        }
      } catch (error) {
        console.error("Failed to fetch news:", error);
        setIsLoadingMore(false);
        if (!filter.companyCode && !filter.date && notifications.length === 0) {
          // setNotifications(MOCK_NOTIFICATIONS); // Optional mock
        } else if (filter.companyCode || filter.date) {
          setNotifications([]);
        }
      }
    };

    // Reset pagination when filters change
    setCurrentPage(1);
    setHasMoreNews(true);
    fetchNews(1, false);
  }, [filter.companyCode, filter.date]);

  // Load more news function
  const loadMoreNews = () => {
    if (isLoadingMore || !hasMoreNews) return;

    setIsLoadingMore(true);
    const nextPage = currentPage + 1;
    setCurrentPage(nextPage);

    const fetchMoreNews = async () => {
      try {
        let url = `${API_BASE_URL}/news?page=${nextPage}&pageSize=50`;

        if (filter.date) {
          // Date endpoint doesn't support pagination, so we can't load more
          setHasMoreNews(false);
          setIsLoadingMore(false);
          return;
        } else if (filter.companyCode) {
          url = `${API_BASE_URL}/news/ticker/${filter.companyCode}?page=${nextPage}&pageSize=50`;
        }

        const response = await fetch(url);
        if (!response.ok) throw new Error('Network response was not ok');
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

        setHasMoreNews(mappedNotifications.length === 50);
        setNotifications(prev => [...prev, ...mappedNotifications]);
        setIsLoadingMore(false);
      } catch (error) {
        console.error("Failed to fetch more news:", error);
        setIsLoadingMore(false);
      }
    };

    fetchMoreNews();
  };

  return (
    <BrowserRouter>
      <AppContent
        theme={theme}
        toggleTheme={toggleTheme}
        companies={companies}
        notifications={notifications}
        setNotifications={setNotifications}
        filter={filter}
        setFilter={setFilter}
        isAdminAuthenticated={isAdminAuthenticated}
        setIsAdminAuthenticated={setIsAdminAuthenticated}
        onLoadMore={loadMoreNews}
        hasMoreNews={hasMoreNews}
        isLoadingMore={isLoadingMore}
      />
    </BrowserRouter>
  );
};

export default App;