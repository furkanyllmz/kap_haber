import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Home, Building2, Info, TrendingUp, Sun, Moon, Menu } from './Icons';
import Footer from './Footer';

interface Props {
  children: React.ReactNode;
  theme: 'dark' | 'light';
  toggleTheme: () => void;
}

const Layout: React.FC<Props> = ({ children, theme, toggleTheme }) => {
  const location = useLocation();
  const navigate = useNavigate();

  const navItems = [
    { id: '/', icon: Home, label: 'Haberler' },
    { id: '/companies', icon: Building2, label: 'Şirketler' },
    { id: '/about', icon: Info, label: 'Hakkında' },
  ];

  const [mobileMenuOpen, setMobileMenuOpen] = React.useState(false);

  const isActive = (path: string) => {
    if (path === '/' && location.pathname === '/') return true;
    if (path !== '/' && location.pathname.startsWith(path)) return true;
    return false;
  };

  return (
    <div className="bg-market-bg min-h-screen text-market-text font-sans transition-colors duration-200 flex flex-col">

      {/* Top Navigation Bar */}
      <header className="sticky top-0 z-50 bg-market-card/95 backdrop-blur-md border-b border-market-border shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">

            {/* Logo Area */}
            <div
              className="flex items-center cursor-pointer group"
              onClick={() => navigate('/')}
            >
              <img
                src={theme === 'dark' ? '/headerlogo_beyaz.png' : '/headerlogo.png'}
                alt="KAP Haber"
                className="h-40 object-contain"
              />
            </div>

            {/* Desktop Navigation */}
            <nav className="hidden md:flex items-center space-x-8">
              {navItems.map((item) => {
                const active = isActive(item.id);
                return (
                  <button
                    key={item.id}
                    onClick={() => navigate(item.id)}
                    className={`text-sm font-medium transition-colors hover:text-market-accent ${active ? 'text-market-accent font-bold' : 'text-market-muted'
                      }`}
                  >
                    {item.label}
                  </button>
                );
              })}

              <div className="h-6 w-px bg-market-border mx-4"></div>

              <button
                onClick={toggleTheme}
                className="p-2 rounded-full hover:bg-market-hover text-market-muted hover:text-market-text transition-colors"
                aria-label="Toggle Theme"
              >
                {theme === 'dark' ? <Sun size={20} /> : <Moon size={20} />}
              </button>
            </nav>

            {/* Mobile Menu Button */}
            <div className="md:hidden flex items-center">
              <button
                onClick={toggleTheme}
                className="p-2 mr-2 rounded-full hover:bg-market-hover text-market-muted"
              >
                {theme === 'dark' ? <Sun size={20} /> : <Moon size={20} />}
              </button>
              <button
                className="p-2 text-market-text"
                onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              >
                <Menu size={24} />
              </button>
            </div>
          </div>
        </div>

        {/* Mobile Navigation Dropdown */}
        {mobileMenuOpen && (
          <div className="md:hidden border-t border-market-border bg-market-card">
            <div className="px-2 pt-2 pb-3 space-y-1 sm:px-3">
              {navItems.map((item) => {
                const active = isActive(item.id);
                return (
                  <button
                    key={item.id}
                    onClick={() => {
                      navigate(item.id);
                      setMobileMenuOpen(false);
                    }}
                    className={`block w-full text-left px-3 py-2 rounded-md text-base font-medium ${active ? 'bg-market-accent/10 text-market-accent' : 'text-market-text hover:bg-market-hover'
                      }`}
                  >
                    <div className="flex items-center">
                      <item.icon size={18} className="mr-3" />
                      {item.label}
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </header>

      {/* Main Content Area */}
      <main className="flex-1 w-full max-w-7xl mx-auto">
        {children}
      </main>

      {/* Footer */}
      <Footer theme={theme} />

    </div>
  );
};

export default Layout;