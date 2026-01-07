import React from 'react';
import { Notification, Company } from '../types';
import { ArrowLeft, Calendar, Clock, Share2, ExternalLink, Tag, TrendingUp } from './Icons';

interface Props {
  notification: Notification;
  onBack: () => void;
  recentNotifications: Notification[];
  onSelectRelated: (id: string) => void;
}

const NotificationDetail: React.FC<Props> = ({ notification, onBack, recentNotifications, onSelectRelated }) => {
  // Simulate full content by repeating summary or adding dummy text
  const fullText = `
    <p class="mb-4 font-serif text-lg leading-relaxed text-market-text">${notification.summary}</p>
    <p class="mb-4 font-serif text-lg leading-relaxed text-market-muted">
      Borsa İstanbul'da işlem gören şirketimiz tarafından Kamuyu Aydınlatma Platformu'na (KAP) yapılan açıklamada detaylar paylaşılmıştır. 
      Söz konusu gelişmenin şirket faaliyetlerine ve finansal tablolara olumlu yansıması beklenmektedir.
    </p>
    <h4 class="text-xl font-bold mt-8 mb-4 text-market-text font-sans">Süreç Nasıl İşleyecek?</h4>
    <p class="mb-4 font-serif text-lg leading-relaxed text-market-muted">
      Yönetim kurulumuzun aldığı karar doğrultusunda, ilgili departmanlar gerekli çalışmalara ivedilikle başlayacaktır. 
      Yatırımcılarımızın doğru bilgilendirilmesi adına süreç şeffaflıkla yürütülecektir. 
      Özellikle ${notification.companyName} pay sahipleri için bu dönemde yapılan açıklamaların takibi önem arz etmektedir.
    </p>
    <p class="mb-4 font-serif text-lg leading-relaxed text-market-muted">
      Ekonomik konjonktür ve sektörel gelişmeler dikkate alındığında, bu adımın orta ve uzun vadeli stratejik hedeflerimizle örtüştüğü görülmektedir.
    </p>
  `;

  return (
    <div className="min-h-screen bg-market-bg animate-fade-in pb-12">
      {/* Navigation Bar for Detail View */}
      <div className="sticky top-0 z-20 bg-market-bg/95 backdrop-blur border-b border-market-border px-4 py-3">
        <div className="max-w-6xl mx-auto flex items-center justify-between">
          <button 
            onClick={onBack}
            className="flex items-center text-market-muted hover:text-market-text transition-colors group"
          >
            <ArrowLeft size={20} className="mr-2 group-hover:-translate-x-1 transition-transform" />
            <span className="font-medium text-sm">Geri Dön</span>
          </button>
          
          <div className="flex items-center space-x-3">
             <button className="p-2 hover:bg-market-card rounded-full text-market-muted hover:text-market-text transition-colors border border-transparent hover:border-market-border">
                <Share2 size={18} />
             </button>
             <a 
                href={notification.kapUrl} 
                target="_blank" 
                rel="noreferrer"
                className="flex items-center px-3 py-1.5 bg-market-accent text-white rounded text-sm font-medium hover:bg-blue-700 transition-colors shadow-sm"
             >
                KAP Kaynağı <ExternalLink size={14} className="ml-2" />
             </a>
          </div>
        </div>
      </div>

      <div className="max-w-6xl mx-auto px-4 py-8 grid grid-cols-1 lg:grid-cols-3 gap-10">
        
        {/* Main Article Column */}
        <div className="lg:col-span-2">
          {/* Article Header */}
          <header className="mb-8 border-b border-market-border pb-8">
            <div className="flex items-center space-x-2 mb-4">
               <span className="bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300 px-2 py-0.5 rounded text-xs font-bold uppercase tracking-wider">
                  KAP Bildirimi
               </span>
               {notification.isImportant && (
                 <span className="bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300 px-2 py-0.5 rounded text-xs font-bold uppercase tracking-wider">
                    Önemli
                 </span>
               )}
            </div>
            
            <h1 className="text-3xl md:text-4xl font-bold text-market-text mb-4 leading-tight font-sans">
              {notification.title}
            </h1>
            
            <div className="flex flex-wrap items-center text-sm text-market-muted gap-4 md:gap-6">
               <div className="flex items-center text-market-text font-medium">
                  <div className={`w-6 h-6 rounded mr-2 flex items-center justify-center text-[10px] font-bold text-white bg-market-accent`}>
                     {notification.companyCode.substring(0, 2)}
                  </div>
                  {notification.companyName}
               </div>
               <div className="flex items-center">
                  <Calendar size={16} className="mr-1.5" />
                  {notification.date}
               </div>
               <div className="flex items-center">
                  <Clock size={16} className="mr-1.5" />
                  {notification.timestamp}
               </div>
            </div>
          </header>

          {/* Featured Image */}
          <figure className="mb-8 rounded-lg overflow-hidden border border-market-border shadow-sm">
             <img 
               src={notification.imageUrl} 
               alt={notification.title} 
               className="w-full h-auto object-cover max-h-[500px]"
             />
             <figcaption className="bg-market-card p-3 text-xs text-center text-market-muted border-t border-market-border">
                {notification.companyName} - Temsili Görsel / KAP
             </figcaption>
          </figure>

          {/* Article Content */}
          <article 
            className="prose dark:prose-invert max-w-none text-market-text"
            dangerouslySetInnerHTML={{ __html: fullText }} 
          />

          {/* Tags */}
          <div className="mt-10 pt-6 border-t border-market-border">
             <h3 className="text-sm font-bold text-market-muted uppercase mb-3 flex items-center">
                <Tag size={16} className="mr-2" />
                İlgili Etiketler
             </h3>
             <div className="flex flex-wrap gap-2">
                {notification.tags.map(tag => (
                   <span key={tag} className="px-3 py-1 bg-market-hover text-market-text rounded-full text-sm hover:bg-market-border cursor-pointer transition-colors">
                      {tag}
                   </span>
                ))}
             </div>
          </div>
        </div>

        {/* Sidebar (Related News) */}
        <aside className="hidden lg:block space-y-8">
           <div className="sticky top-24">
              <div className="bg-market-card border border-market-border rounded-lg shadow-sm p-5">
                 <h3 className="font-bold text-market-text text-lg mb-4 flex items-center border-b border-market-border pb-2">
                    <TrendingUp size={20} className="mr-2 text-market-green" />
                    Son Dakika
                 </h3>
                 <div className="space-y-4">
                    {recentNotifications.filter(n => n.id !== notification.id).slice(0, 5).map(item => (
                       <div 
                          key={item.id} 
                          onClick={() => onSelectRelated(item.id)}
                          className="group cursor-pointer"
                       >
                          <div className="text-xs text-market-muted mb-1 flex justify-between">
                             <span className="text-market-accent font-bold">{item.companyCode}</span>
                             <span>{item.timestamp}</span>
                          </div>
                          <h4 className="text-sm font-medium text-market-text group-hover:text-market-accent transition-colors line-clamp-2 leading-snug">
                             {item.title}
                          </h4>
                          <div className="border-b border-market-border mt-3 group-last:border-0"></div>
                       </div>
                    ))}
                 </div>
                 <button 
                    onClick={onBack}
                    className="w-full mt-4 text-center text-xs text-market-muted hover:text-market-text font-medium py-2 border border-market-border rounded hover:bg-market-hover transition-colors"
                 >
                    Tüm Haberleri Gör
                 </button>
              </div>

              {/* Market Data Widget Mockup */}
              <div className="mt-6 bg-market-card border border-market-border rounded-lg shadow-sm p-5">
                 <h3 className="font-bold text-market-text text-sm mb-3 text-center">BIST 100 Özet</h3>
                 <div className="grid grid-cols-2 gap-2 text-center">
                    <div className="p-2 bg-market-green/10 rounded">
                       <div className="text-xs text-market-muted">Yükselen</div>
                       <div className="text-market-green font-bold text-lg">64</div>
                    </div>
                    <div className="p-2 bg-market-red/10 rounded">
                       <div className="text-xs text-market-muted">Düşen</div>
                       <div className="text-market-red font-bold text-lg">36</div>
                    </div>
                 </div>
              </div>
           </div>
        </aside>
      </div>
    </div>
  );
};

export default NotificationDetail;