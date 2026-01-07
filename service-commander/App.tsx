import React, { useState, useEffect } from 'react';
import { Activity, RefreshCw, Server, ShieldCheck } from 'lucide-react';
import { ServiceInfo, PYTHON_API_URL } from './types';
import ServiceCard from './components/ServiceCard';
import LogTerminal from './components/LogTerminal';

const MOCK_SERVICES: ServiceInfo[] = [
    { name: 'pipeline', status: 'running', pid: 14023 },
    { name: 'analyzer', status: 'running', pid: 14055 },
    { name: 'twitterbot', status: 'stopped', pid: null },
    { name: 'financials', status: 'running', pid: 15100 },
    { name: 'fetch_symbols', status: 'stopped', pid: null },
    { name: 'extract_logos', status: 'unknown', pid: null },
];

const App: React.FC = () => {
    const [services, setServices] = useState<ServiceInfo[]>([]);
    const [loading, setLoading] = useState(false);
    const [actionLoading, setActionLoading] = useState<string | null>(null);
    const [selectedServiceLogs, setSelectedServiceLogs] = useState<string | null>(null);

    const fetchServices = async () => {
        setLoading(true);
        try {
            // Attempt to fetch from real API
            const res = await fetch(`${PYTHON_API_URL}/services`);
            if (res.ok) {
                const data = await res.json();
                setServices(data);
            } else {
                throw new Error("API not reachable");
            }
        } catch (err) {
            console.warn("Failed to fetch services, using mock data:", err);
            // Fallback to mock data for demonstration
            setServices(MOCK_SERVICES);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchServices();
        const interval = setInterval(fetchServices, 10000);
        return () => clearInterval(interval);
    }, []);

    const handleAction = async (name: string, action: 'start' | 'stop') => {
        setActionLoading(name);
        try {
            const res = await fetch(`${PYTHON_API_URL}/services/${name}/${action}`, {
                method: 'POST'
            });
            if (!res.ok) throw new Error(`Failed to ${action} service`);
            
            setTimeout(fetchServices, 500);
        } catch (err) {
            console.log(`Mock action: ${action} ${name}`);
            // Update local state for mock feel
            setServices(prev => prev.map(s => {
                if (s.name === name) {
                    return {
                        ...s,
                        status: action === 'start' ? 'running' : 'stopped',
                        pid: action === 'start' ? Math.floor(Math.random() * 9000) + 1000 : null
                    };
                }
                return s;
            }));
        } finally {
            // Add a little artificial delay to show the loading state
            setTimeout(() => setActionLoading(null), 800);
        }
    };

    const activeServicesCount = services.filter(s => s.status === 'running').length;

    return (
        <div className="min-h-screen bg-slate-50 text-slate-900 pb-20">
            {/* Header / Navbar */}
            <header className="bg-white border-b border-slate-200 sticky top-0 z-10">
                <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <div className="bg-indigo-600 p-2 rounded-lg text-white">
                            <ShieldCheck className="w-6 h-6" />
                        </div>
                        <div>
                            <h1 className="text-xl font-bold tracking-tight text-slate-900">Service Commander</h1>
                            <div className="flex items-center gap-2 text-xs text-slate-500">
                                <span className="w-2 h-2 rounded-full bg-green-500"></span>
                                System Online
                            </div>
                        </div>
                    </div>

                    <div className="flex items-center gap-4">
                        <div className="hidden sm:flex items-center gap-4 px-4 py-1.5 bg-slate-100 rounded-full border border-slate-200 text-sm font-medium text-slate-600">
                            <div className="flex items-center gap-2">
                                <Server className="w-4 h-4 text-slate-400" />
                                <span>Total: <span className="text-slate-900">{services.length}</span></span>
                            </div>
                            <div className="w-[1px] h-4 bg-slate-300"></div>
                            <div className="flex items-center gap-2">
                                <Activity className="w-4 h-4 text-green-500" />
                                <span>Running: <span className="text-slate-900">{activeServicesCount}</span></span>
                            </div>
                        </div>

                        <button
                            onClick={fetchServices}
                            disabled={loading}
                            className={`p-2 rounded-full hover:bg-slate-100 border border-transparent hover:border-slate-200 transition-all ${loading ? 'text-indigo-600' : 'text-slate-500'}`}
                            title="Refresh Data"
                        >
                            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
                        </button>
                    </div>
                </div>
            </header>

            {/* Main Content */}
            <main className="max-w-6xl mx-auto px-4 py-8">
                {/* Stats or Banner area could go here */}
                
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {services.map((svc) => (
                        <ServiceCard 
                            key={svc.name}
                            service={svc}
                            onAction={handleAction}
                            onViewLogs={(name) => setSelectedServiceLogs(name)}
                            isProcessing={actionLoading === svc.name}
                        />
                    ))}
                    
                    {services.length === 0 && !loading && (
                        <div className="col-span-full py-12 flex flex-col items-center justify-center text-slate-400 border-2 border-dashed border-slate-200 rounded-xl bg-slate-50/50">
                            <Server className="w-12 h-12 mb-4 opacity-50" />
                            <p className="text-lg font-medium text-slate-500">No Services Found</p>
                            <p className="text-sm">Is the backend running at {PYTHON_API_URL}?</p>
                        </div>
                    )}
                </div>
            </main>

            {/* Modal Logic */}
            {selectedServiceLogs && (
                <LogTerminal 
                    serviceName={selectedServiceLogs}
                    onClose={() => setSelectedServiceLogs(null)}
                />
            )}
        </div>
    );
};

export default App;