import React from 'react';
import { useNavigate } from 'react-router-dom';
import { BellRing, TrendingUp, Filter, Info, LayoutDashboard } from './Icons';

const AboutView: React.FC = () => {
  const navigate = useNavigate();

  return (
    <div className="min-h-screen bg-market-bg flex flex-col relative overflow-hidden pb-24 lg:pb-0">
      {/* Background Decorative Elements */}
      <div className="absolute top-0 right-0 w-96 h-96 bg-market-green/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2 dark:opacity-100 opacity-60"></div>
      <div className="absolute bottom-0 left-0 w-96 h-96 bg-market-accent/10 rounded-full blur-3xl translate-y-1/3 -translate-x-1/3 dark:opacity-100 opacity-60"></div>

      <div className="flex-1 px-6 pt-12 lg:pt-0 flex flex-col lg:flex-row items-center justify-center lg:gap-20 z-10 max-w-7xl mx-auto w-full">

        {/* Left Side: Hero Text */}
        <div className="flex flex-col items-center lg:items-start text-center lg:text-left mb-10 lg:mb-0 max-w-lg">
          <div className="mb-8 relative inline-block">
            <div className="w-24 h-24 lg:w-32 lg:h-32 bg-gradient-to-tr from-market-card to-market-border rounded-3xl border border-market-border flex items-center justify-center shadow-2xl relative z-10">
              <TrendingUp size={48} className="text-market-green lg:w-16 lg:h-16" />
            </div>
            <div className="absolute inset-0 bg-market-green/30 blur-2xl rounded-full animate-pulse-slow"></div>
          </div>

          <h1 className="text-4xl lg:text-6xl font-extrabold text-market-text mb-6 tracking-tight">
            KAP <span className="text-transparent bg-clip-text bg-gradient-to-r from-market-green to-blue-500">Haber </span>
          </h1>

          <p className="text-market-muted text-lg lg:text-xl mb-10 leading-relaxed">
            Borsa İstanbul şirketlerinin en kritik bildirimlerini anlık takip edin, akıllı filtrelerle fırsatları kaçırmayın.
          </p>

          <button
            onClick={() => navigate('/')}
            className="w-full lg:w-auto px-8 bg-gradient-to-r from-market-accent to-blue-600 hover:from-blue-600 hover:to-blue-700 text-white font-bold py-4 rounded-xl shadow-lg shadow-blue-500/30 transform transition-all active:scale-95 flex items-center justify-center hover:-translate-y-1"
          >
            Uygulamaya Başla
            <TrendingUp size={20} className="ml-2" />
          </button>
        </div>

        {/* Right Side: Feature Grid (Desktop) or List (Mobile) */}
        <div className="w-full max-w-md space-y-4 lg:space-y-6">

          <div className="flex items-start space-x-4 p-5 bg-market-card/80 border border-market-border rounded-2xl backdrop-blur-sm animate-slide-up shadow-sm hover:shadow-md transition-shadow" style={{ animationDelay: '0.1s' }}>
            <div className="bg-blue-500/10 p-3 rounded-xl text-blue-500">
              <BellRing size={28} />
            </div>
            <div>
              <h3 className="font-bold text-market-text text-lg">Anlık Bildirimler</h3>
              <p className="text-sm text-market-muted mt-1 leading-relaxed">Önemli KAP açıklamaları anında ekranınızda. Karmaşık metinler yerine özetlenmiş bilgi.</p>
            </div>
          </div>

          <div className="flex items-start space-x-4 p-5 bg-market-card/80 border border-market-border rounded-2xl backdrop-blur-sm animate-slide-up shadow-sm hover:shadow-md transition-shadow" style={{ animationDelay: '0.2s' }}>
            <div className="bg-green-500/10 p-3 rounded-xl text-green-500">
              <Filter size={28} />
            </div>
            <div>
              <h3 className="font-bold text-market-text text-lg">Akıllı Filtreleme</h3>
              <p className="text-sm text-market-muted mt-1 leading-relaxed">Takip ettiğiniz hisseleri veya belirli tarih aralıklarını kolayca filtreleyin.</p>
            </div>
          </div>

          <div className="flex items-start space-x-4 p-5 bg-market-card/80 border border-market-border rounded-2xl backdrop-blur-sm animate-slide-up shadow-sm hover:shadow-md transition-shadow" style={{ animationDelay: '0.3s' }}>
            <div className="bg-purple-500/10 p-3 rounded-xl text-purple-500">
              <LayoutDashboard size={28} />
            </div>
            <div>
              <h3 className="font-bold text-market-text text-lg">Web ve Mobil Uyumlu</h3>
              <p className="text-sm text-market-muted mt-1 leading-relaxed">Hem masaüstü hem mobil cihazlarınızda kesintisiz deneyim ve Dark Mode desteği.</p>
            </div>
          </div>

        </div>
      </div>
    </div>
  );
};

export default AboutView;