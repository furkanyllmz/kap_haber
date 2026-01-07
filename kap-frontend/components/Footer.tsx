import React from 'react';
import { TrendingUp, TwitterX, Smartphone } from './Icons';

interface FooterProps {
  theme: 'dark' | 'light';
}

const Footer: React.FC<FooterProps> = ({ theme }) => {
  return (
    <footer className="bg-market-card border-t border-market-border mt-auto">
      <div className="max-w-7xl mx-auto px-4 py-12 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8">
          {/* Brand */}
          <div className="col-span-1 md:col-span-1">
            <div className="flex items-center mb-4">
              <img
                src={theme === 'dark' ? '/headerlogo_beyaz.png' : '/headerlogo.png'}
                alt="KAP Haber"
                className="h-32 object-contain"
              />
            </div>
            <p className="text-sm text-market-muted leading-relaxed">
              Borsa İstanbul şirketlerinin KAP bildirimlerini anlık takip edin, finans dünyasından kopmayın.
            </p>
          </div>

          {/* Quick Links */}
          <div>
            <h3 className="text-sm font-bold text-market-text uppercase tracking-wider mb-4">Menü</h3>
            <ul className="space-y-3">
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Ana Sayfa</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Haberler</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Şirketler</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Hakkında</button></li>
            </ul>
          </div>

          {/* Legal / Info */}
          <div>
            <h3 className="text-sm font-bold text-market-text uppercase tracking-wider mb-4">Kurumsal</h3>
            <ul className="space-y-3">
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Kullanım Koşulları</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Gizlilik Politikası</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">Çerez Politikası</button></li>
              <li><button className="text-sm text-market-muted hover:text-market-accent transition-colors">İletişim</button></li>
            </ul>
          </div>

          {/* Social & App */}
          <div>
            <h3 className="text-sm font-bold text-market-text uppercase tracking-wider mb-4">Bizi Takip Edin</h3>
            <a href="#" className="inline-flex items-center text-market-muted hover:text-market-text transition-colors mb-6 group">
              <TwitterX size={18} className="mr-2 group-hover:scale-110 transition-transform" />
              <span className="text-sm font-medium">@kap_haberlerii</span>
            </a>

            <h3 className="text-sm font-bold text-market-text uppercase tracking-wider mb-3">Mobil Uygulama</h3>
            <div className="flex flex-col space-y-2">
              <button className="flex items-center justify-center px-4 py-2 bg-market-text text-market-bg rounded-lg hover:opacity-90 transition-opacity">
                <Smartphone size={18} className="mr-2" />
                <span className="text-xs font-bold">App Store'dan İndir</span>
              </button>
              <button className="flex items-center justify-center px-4 py-2 border border-market-border text-market-text rounded-lg hover:bg-market-hover transition-colors">
                <Smartphone size={18} className="mr-2" />
                <span className="text-xs font-bold">Google Play'den İndir</span>
              </button>
            </div>
          </div>
        </div>

        <div className="mt-12 pt-8 border-t border-market-border flex flex-col md:flex-row justify-between items-center">
          <p className="text-xs text-market-muted">
            &copy; 2025 KAP Haber Pro. Tüm hakları saklıdır. Veriler BİST kaynaklıdır.
          </p>
          <div className="flex space-x-4 mt-4 md:mt-0">
            <span className="text-xs text-market-muted">v1.0.2</span>
          </div>
        </div>
      </div>
    </footer>
  );
};

export default Footer;