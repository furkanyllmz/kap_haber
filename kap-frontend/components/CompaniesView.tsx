import React, { useState } from 'react';
import { Company } from '../types';
import { Search, ChevronRight } from './Icons';

interface Props {
  companies: Company[];
  onSelectCompany: (code: string) => void;
}

const CompaniesView: React.FC<Props> = ({ companies, onSelectCompany }) => {
  const [search, setSearch] = useState('');

  const filteredCompanies = companies.filter(c =>
    c.name.toLowerCase().includes(search.toLowerCase()) ||
    c.code.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="pb-24 lg:pb-8 pt-4 px-4 min-h-screen">
      <div className="sticky top-14 lg:top-0 z-30 -mx-4 px-4 py-3 bg-market-bg/95 backdrop-blur-md border-b border-market-border mb-6">
        <div className="max-w-7xl mx-auto">
          <h1 className="text-2xl font-bold text-market-text mb-4">BIST Şirketleri</h1>

          {/* Search Bar */}
          <div className="relative">
            <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
              <Search size={18} className="text-market-muted" />
            </div>
            <input
              type="text"
              placeholder="Hisse kodu veya şirket ara..."
              className="block w-full pl-10 pr-3 py-3 border border-market-border rounded-xl leading-5 bg-market-card text-market-text placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-market-accent focus:border-market-accent sm:text-sm transition-all shadow-sm"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          </div>
        </div>
      </div>

      {/* Grid */}
      <div className="max-w-7xl mx-auto grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        {filteredCompanies.map((company) => (
          <div
            key={company.code}
            onClick={() => onSelectCompany(company.code)}
            className="flex items-center justify-between p-4 bg-market-card border border-market-border rounded-xl hover:border-market-accent/50 hover:shadow-md active:scale-[0.99] transition-all cursor-pointer group"
          >
            <div className="flex items-center space-x-4">
              <div className={`w-12 h-12 rounded-lg ${company.logoColor} flex items-center justify-center text-white font-bold text-sm shadow-md relative overflow-hidden`}>
                <span className="z-0">{company.code.substring(0, 2)}</span>
                {company.logoUrl && (
                  <img
                    src={company.logoUrl}
                    alt={company.code}
                    className="absolute inset-0 w-full h-full object-contain bg-white"
                    onError={(e) => { e.currentTarget.style.display = 'none' }}
                  />
                )}
              </div>
              <div>
                <h3 className="text-market-text font-bold text-lg group-hover:text-market-accent transition-colors">{company.code}</h3>
                <p className="text-market-muted text-sm truncate max-w-[180px]">{company.name}</p>
              </div>
            </div>
            <div className="flex items-center text-market-muted group-hover:text-market-accent transition-colors">
              <ChevronRight size={20} />
            </div>
          </div>
        ))}
      </div>

      {filteredCompanies.length === 0 && (
        <div className="text-center py-20 text-market-muted">
          <p className="text-lg">Sonuç bulunamadı.</p>
        </div>
      )}
    </div>
  );
};

export default CompaniesView;