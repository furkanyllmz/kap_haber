import React from 'react';
import { TwitterX, Smartphone } from './Icons';

interface FooterProps {
  theme: 'dark' | 'light';
}

const Footer: React.FC<FooterProps> = ({ theme }) => {
  return (
    <footer className="bg-market-card border-t border-market-border mt-auto">
      <div className="max-w-7xl mx-auto px-4 py-8 sm:px-6 lg:px-8">
        {/* Three Column Layout */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">
          {/* Left Column - Navigation Menu */}
          <div className="flex flex-col gap-3">
            <button className="text-sm text-market-muted hover:text-market-accent transition-colors text-left">
              Haberler
            </button>
            <button className="text-sm text-market-muted hover:text-market-accent transition-colors text-left">
              Şirketler
            </button>
            <button className="text-sm text-market-muted hover:text-market-accent transition-colors text-left">
              Hakkında
            </button>
          </div>

          {/* Center Column - Contact Info */}
          <div className="flex flex-col gap-4">
            <h3 className="text-base font-semibold text-market-text">İletişim</h3>

            <div className="flex flex-col gap-3">
              <a
                href="mailto:kap.haberanlik@gmail.com"
                className="flex items-center gap-2 text-sm text-market-muted hover:text-market-accent transition-colors"
              >
                <svg className="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                </svg>
                <span>kap.haberanlik@gmail.com</span>
              </a>
            </div>
          </div>

          {/* Right Column - Social Media */}
          <div className="flex flex-col gap-4">
            <h3 className="text-base font-semibold text-market-text">Sosyal Medya</h3>

            <div className="flex items-center gap-4">
              {/* Twitter/X */}
              <a
                href="https://x.com/kap_haberlerii"
                target="_blank"
                rel="noopener noreferrer"
                className="w-10 h-10 rounded-full border border-market-border flex items-center justify-center text-market-muted hover:text-market-accent hover:border-market-accent transition-all"
                aria-label="Twitter/X"
              >
                <TwitterX size={20} />
              </a>

              {/* Google Play */}
              <a
                href="#"
                className="w-10 h-10 rounded-full border border-market-border flex items-center justify-center text-market-muted hover:text-market-accent hover:border-market-accent transition-all"
                aria-label="Get it on Google Play"
              >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M3.609 1.814L13.792 12 3.61 22.186a.996.996 0 0 1-.61-.92V2.734a1 1 0 0 1 .609-.92zm10.89 10.893l2.302 2.302-10.937 6.333 8.635-8.635zm3.199-3.198l2.807 1.626a1 1 0 0 1 0 1.73l-2.808 1.626L15.206 12l2.492-2.491zM5.864 2.658L16.802 8.99l-2.303 2.303-8.635-8.635z" />
                </svg>
              </a>

              {/* App Store */}
              <a
                href="#"
                className="w-10 h-10 rounded-full border border-market-border flex items-center justify-center text-market-muted hover:text-market-accent hover:border-market-accent transition-all"
                aria-label="Download on App Store"
              >
                <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z" />
                </svg>
              </a>
            </div>
          </div>
        </div>

        {/* Copyright */}
        <div className="mt-8 pt-6 border-t border-market-border text-center">
          <p className="text-xs text-market-muted">
            &copy; 2025 KAP Haber. Tüm hakları saklıdır. Veriler KAP kaynaklıdır.
          </p>
        </div>
      </div>
    </footer>
  );
};

export default Footer;