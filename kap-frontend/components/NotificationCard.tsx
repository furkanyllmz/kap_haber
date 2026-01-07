import React from 'react';
import { Notification } from '../types';
import { Clock, ChevronRight, BellRing } from './Icons';

interface Props {
  notification: Notification;
  onClick: () => void;
  variant?: 'grid' | 'list';
}

const NotificationCard: React.FC<Props> = ({ notification, onClick, variant = 'grid' }) => {
  if (variant === 'list') {
    // Twitter-style layout for company view
    return (
      <article
        className="group bg-market-card border border-market-border rounded-xl p-4 hover:bg-market-hover/50 transition-colors cursor-pointer flex gap-4 shadow-sm"
        onClick={onClick}
      >
        {/* Avatar / Logo Column */}
        <div className="flex-shrink-0">
          <div className="w-12 h-12 rounded-full bg-market-accent/10 flex items-center justify-center text-market-accent font-bold text-sm border border-market-accent/20">
            {notification.companyCode.substring(0, 2)}
          </div>
        </div>

        {/* Content Column */}
        <div className="flex-1 min-w-0">
          <div className="flex justify-between items-start mb-1">
            <div className="flex items-center space-x-2 text-sm">
              <span className="font-bold text-market-text">{notification.companyName}</span>
              <span className="text-market-muted text-xs">@{notification.companyCode}</span>
              <span className="text-market-muted text-xs">• {notification.timestamp}</span>
            </div>
            {notification.isImportant && (
              <BellRing size={14} className="text-market-red" />
            )}
          </div>

          <p className="text-market-text text-base leading-snug mb-3 font-sans">
            {notification.title}
          </p>
          <p className="text-market-muted text-sm leading-relaxed mb-3">
            {notification.summary}
          </p>

          {/* Image Attachment */}
          <div className="relative w-full h-64 rounded-xl overflow-hidden border border-market-border mt-2">
            <img
              src={notification.imageUrl}
              alt={notification.title}
              className="w-full h-full object-cover"
            />

            {/* Company Logo Overlay */}
            <div className="absolute top-3 left-3 w-16 h-16 flex items-center justify-center">
              <img
                src={`http://localhost:5296/logos/${notification.companyCode}.svg`}
                alt={notification.companyCode}
                className="w-full h-full object-contain drop-shadow-lg"
                onError={(e) => {
                  e.currentTarget.style.display = 'none';
                  const parent = e.currentTarget.parentElement;
                  if (parent) {
                    parent.innerHTML = `<div class="bg-white/90 backdrop-blur-sm px-2 py-1 rounded shadow-lg"><span class="text-xs font-bold text-gray-700">${notification.companyCode}</span></div>`;
                  }
                }}
              />
            </div>
          </div>

          <div className="flex items-center justify-between mt-3 pt-2">
            <span className="text-xs text-market-accent hover:underline flex items-center">
              Detayları Görüntüle <ChevronRight size={12} className="ml-1" />
            </span>
            <span className="text-xs text-market-muted">{notification.date}</span>
          </div>
        </div>
      </article>
    );
  }

  // Default Grid Layout
  return (
    <article
      className="group bg-market-card border border-market-border rounded-lg overflow-hidden hover:border-market-accent/50 transition-all duration-200 cursor-pointer flex flex-col h-full shadow-sm hover:shadow-md"
      onClick={onClick}
    >
      {/* Image Section */}
      <div className="relative h-48 w-full overflow-hidden bg-gray-100 dark:bg-gray-800">
        <img
          src={notification.imageUrl}
          alt={notification.title}
          className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
        />

        {/* Company Logo Overlay */}
        <div className="absolute top-3 left-3 w-14 h-14 flex items-center justify-center">
          <img
            src={`http://localhost:5296/logos/${notification.companyCode}.svg`}
            alt={notification.companyCode}
            className="w-full h-full object-contain drop-shadow-lg"
            onError={(e) => {
              e.currentTarget.style.display = 'none';
              const parent = e.currentTarget.parentElement;
              if (parent) {
                parent.innerHTML = `<div class="bg-white/90 backdrop-blur-sm px-2 py-1 rounded shadow-lg"><span class="text-xs font-bold text-gray-700">${notification.companyCode}</span></div>`;
              }
            }}
          />
        </div>

        {notification.isImportant && (
          <div className="absolute top-3 right-3 bg-red-600 text-white text-xs font-bold px-2 py-1 rounded flex items-center shadow-sm">
            <BellRing size={10} className="mr-1" />
            KRİTİK
          </div>
        )}
      </div>

      {/* Content Section */}
      <div className="p-4 flex-1 flex flex-col">
        <div className="flex items-center text-xs text-market-muted mb-2 space-x-2">
          <span className="font-medium text-market-accent">{notification.companyName}</span>
          <span>•</span>
          <span className="flex items-center">
            <Clock size={12} className="mr-1" />
            {notification.timestamp}
          </span>
        </div>

        <h3 className="text-lg font-bold text-market-text leading-tight mb-2 group-hover:text-market-accent transition-colors font-sans">
          {notification.title}
        </h3>

        <p className="text-sm text-market-muted line-clamp-2 mb-4 flex-1">
          {notification.summary}
        </p>

        <div className="pt-3 border-t border-market-border flex items-center justify-between mt-auto">
          <span className="text-xs text-market-muted">{notification.date}</span>
          <span className="text-xs font-medium text-market-accent flex items-center group-hover:translate-x-1 transition-transform">
            Haberi Oku
            <ChevronRight size={16} className="ml-1" />
          </span>
        </div>
      </div>
    </article>
  );
};

export default NotificationCard;