import React from 'react';
import { TrendingUp, TwitterX, Smartphone } from './Icons';

const Footer: React.FC = () => {
  return (
    <footer className="bg-market-card border-t border-market-border mt-auto">
      <div className="max-w-7xl mx-auto px-4 py-12 sm:px-6 lg:px-8">
        <div className="flex flex-col md:flex-row justify-center items-start gap-12 md:gap-16 text-center md:text-left">
          {/* Brand */}
          <div className="flex flex-col items-center md:items-start">
            <div className="flex items-center space-x-2 mb-4">
              <div className="bg-market-text text-market-bg p-1.5 rounded-lg">
                <TrendingUp size={20} />
              </div>
              <span className="text-xl font-serif font-bold tracking-tight text-market-text">KAP Haber</span>
            </div>
            <p className="text-sm text-market-muted leading-relaxed max-w-[200px]">
              Borsa İstanbul şirketlerinin KAP bildirimlerini anlık takip edin, finans dünyasından kopmayın.
            </p>
          </div>

          {/* Quick Links */}
          <div className="flex flex-col items-center md:items-start">
            <h3 className="text-sm font-bold text-market-text uppercase tracking-wider mb-4">Menü</h3>
            <ul className="space-y-3">
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Ana Sayfa</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Haberler</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Şirketler</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Hakkında</button></li>
            </ul>
          </div>

          {/* Contact & Social */}
          <div className="flex flex-col items-center md:items-start space-y-3">
            <h3 className="text-sm font-bold text-market-text uppercase tracking-wider">İletişim</h3>

            {/* Email */}
            <a
              href="mailto:kap.haberanlik@gmail.com"
              className="text-sm text-market-muted hover:text-market-accent transition-colors flex items-center"
            >
              <svg className="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
              </svg>
              kap.haberanlik@gmail.com
            </a>

            {/* Twitter/X */}
            <a href="#" className="inline-flex items-center text-market-muted hover:text-market-text transition-colors group">
              <TwitterX size={18} className="mr-2 group-hover:scale-110 transition-transform" />
              <span className="text-sm font-medium">@kap_haberlerii</span>
            </a>

            {/* Mobile Apps */}
            <div className="flex flex-col space-y-2 w-full mt-2">
              <p className="text-xs font-semibold text-market-text">Mobil Uygulamamızı İndirin!</p>
              <button className="flex items-center justify-center px-4 py-2 bg-market-text text-market-bg rounded-lg hover:opacity-90 transition-opacity text-xs">
                <Smartphone size={16} className="mr-2" />
                <span className="font-bold">App Store'dan İndir</span>
              </button>
              <button className="flex items-center justify-center px-4 py-2 border border-market-border text-market-text rounded-lg hover:bg-market-hover transition-colors text-xs">
                <Smartphone size={16} className="mr-2" />
                <span className="font-bold">Google Play'den İndir</span>
              </button>
            </div>
          </div>
        </div>

        <div className="mt-12 pt-8 border-t border-market-border flex flex-col md:flex-row justify-between items-center">
          <p className="text-xs text-market-muted">
            &copy; 2025 KAP Haber. Tüm hakları saklıdır. Veriler KAP kaynaklıdır.
          </p>
          <div className="flex space-x-4 mt-4 md:mt-0">
            <span className="text-xs text-market-muted"></span>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;