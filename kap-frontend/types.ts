export interface Company {
  code: string;
  name: string;
  logoColor: string;
  logoUrl?: string; // Add this
}

export interface Notification {
  id: string;
  companyCode: string;
  companyName: string;
  title: string;
  summary: string;
  imageUrl: string;
  date: string; // ISO date string YYYY-MM-DD
  timestamp: string; // HH:mm
  kapUrl: string;
  tags: string[];
  isImportant: boolean;
}

export type ViewState = 'feed' | 'companies' | 'about' | 'detail' | 'companyDetail' | 'admin';

export interface FilterState {
  date: string | null;
  companyCode: string | null;
}

export interface PriceItem {
  id: string;
  ticker: string;
  updatedAt: string;
  extraElements: {
    DailyChangePercent?: number;
    DailyChange?: number;
    Last?: number;
    [key: string]: any;
  };
}