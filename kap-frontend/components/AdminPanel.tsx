import React, { useState, useEffect } from 'react';
import { Play, Square, FileText, RefreshCw, Activity, Terminal } from 'lucide-react';

// Do not use API_BASE_URL from constants as it points to Dotnet backend (5296)
const PYTHON_API_URL = "http://localhost:8000";

interface ServiceInfo {
    name: string;
    status: 'running' | 'stopped' | 'unknown';
    pid: number | null;
}

interface LogData {
    name: string;
    lines: number;
    content: string;
}

const AdminPanel: React.FC = () => {
    const [services, setServices] = useState<ServiceInfo[]>([]);
    const [loading, setLoading] = useState(false);
    const [selectedLogs, setSelectedLogs] = useState<LogData | null>(null);
    const [logLoading, setLogLoading] = useState(false);

    // Configuration for pretty names/descriptions
    const serviceMeta: Record<string, { label: string; desc: string }> = {
        pipeline: { label: 'Daily Pipeline', desc: 'Main automation pipeline' },
        analyzer: { label: 'News Analyzer', desc: 'Processes raw news items' },
        twitterbot: { label: 'Twitter Bot', desc: 'Posts updates to X' },
        financials: { label: 'Fetch Financials', desc: 'Scrapes financial data' },
        fetch_symbols: { label: 'Fetch Symbols', desc: 'Updates ticker list' },
        extract_logos: { label: 'Logo Extractor', desc: 'Downloads company logos' },
    };

    const fetchServices = async () => {
        setLoading(true);
        try {
            const res = await fetch(`${PYTHON_API_URL}/services`);
            if (res.ok) {
                const data = await res.json();
                setServices(data);
            }
        } catch (err) {
            console.error("Failed to fetch services:", err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchServices();
        // Auto refresh every 10s
        const interval = setInterval(fetchServices, 10000);
        return () => clearInterval(interval);
    }, []);

    const handleAction = async (name: string, action: 'start' | 'stop') => {
        try {
            setLoading(true);
            const res = await fetch(`${PYTHON_API_URL}/services/${name}/${action}`, {
                method: 'POST'
            });
            if (!res.ok) throw new Error(`Failed to ${action} service`);
            await fetchServices();
        } catch (err) {
            alert(`Error: ${err}`);
        } finally {
            setLoading(false);
        }
    };

    const showLogs = async (name: string) => {
        setLogLoading(true);
        try {
            const res = await fetch(`${PYTHON_API_URL}/services/${name}/logs?lines=100`);
            if (res.ok) {
                const data = await res.json();
                setSelectedLogs(data);
            }
        } catch (err) {
            console.error(err);
        } finally {
            setLogLoading(false);
        }
    };

    return (
        <div className="max-w-6xl mx-auto p-4 space-y-6">
            <div className="flex justify-between items-center mb-6">
                <div>
                    <h2 className="text-2xl font-bold dark:text-white flex items-center gap-2">
                        <Activity className="text-indigo-500" />
                        Servis Yönetimi
                    </h2>
                    <p className="text-slate-500 text-sm mt-1">Arka plan servislerini yönetin ve izleyin</p>
                </div>
                <button
                    onClick={fetchServices}
                    disabled={loading}
                    className="p-2 bg-slate-100 dark:bg-slate-800 rounded-full hover:bg-slate-200 dark:hover:bg-slate-700 transition"
                >
                    <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin text-indigo-500' : 'text-slate-600 dark:text-slate-400'}`} />
                </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                {services.map((svc) => {
                    const isRunning = svc.status === 'running';
                    const meta = serviceMeta[svc.name] || { label: svc.name, desc: 'Unknown Service' };

                    return (
                        <div key={svc.name} className="bg-white dark:bg-slate-800 rounded-xl shadow-sm border border-slate-200 dark:border-slate-700 p-4 transition hover:shadow-md">
                            <div className="flex justify-between items-start mb-3">
                                <div className="flex items-center gap-3">
                                    <div className={`w-3 h-3 rounded-full ${isRunning ? 'bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)]' : 'bg-red-500'}`} />
                                    <div>
                                        <h3 className="font-bold text-lg dark:text-white">{meta.label}</h3>
                                        <p className="text-xs text-slate-500 dark:text-slate-400 font-mono">{svc.name}</p>
                                    </div>
                                </div>
                                {isRunning && (
                                    <span className="text-xs font-mono bg-slate-100 dark:bg-slate-900 text-slate-500 px-2 py-1 rounded">
                                        PID: {svc.pid}
                                    </span>
                                )}
                            </div>

                            <p className="text-sm text-slate-600 dark:text-slate-300 mb-4 h-5">
                                {meta.desc}
                            </p>

                            <div className="flex gap-2 mt-auto pt-2 border-t border-slate-100 dark:border-slate-700">
                                {!isRunning ? (
                                    <button
                                        onClick={() => handleAction(svc.name, 'start')}
                                        disabled={loading}
                                        className="flex-1 flex items-center justify-center gap-2 py-1.5 bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400 rounded-lg hover:bg-green-100 dark:hover:bg-green-900/40 transition text-sm font-medium"
                                    >
                                        <Play className="w-4 h-4" /> Başlat
                                    </button>
                                ) : (
                                    <button
                                        onClick={() => handleAction(svc.name, 'stop')}
                                        disabled={loading}
                                        className="flex-1 flex items-center justify-center gap-2 py-1.5 bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 rounded-lg hover:bg-red-100 dark:hover:bg-red-900/40 transition text-sm font-medium"
                                    >
                                        <Square className="w-4 h-4 fill-current" /> Durdur
                                    </button>
                                )}

                                <button
                                    onClick={() => showLogs(svc.name)}
                                    className="flex items-center justify-center p-2 bg-slate-100 dark:bg-slate-900 text-slate-600 dark:text-slate-400 rounded-lg hover:bg-slate-200 dark:hover:bg-slate-800 transition"
                                    title="Logları Gör"
                                >
                                    <FileText className="w-4 h-4" />
                                </button>
                            </div>
                        </div>
                    );
                })}
            </div>

            {/* Log Viewer Modal */}
            {selectedLogs && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
                    <div className="bg-white dark:bg-slate-900 w-full max-w-4xl rounded-xl shadow-2xl flex flex-col max-h-[85vh]">
                        <div className="p-4 border-b border-slate-200 dark:border-slate-700 flex justify-between items-center bg-slate-50 dark:bg-slate-800/50 rounded-t-xl">
                            <h3 className="font-bold flex items-center gap-2 dark:text-white">
                                <Terminal className="w-5 h-5 text-indigo-500" />
                                {serviceMeta[selectedLogs.name]?.label || selectedLogs.name} Logs
                            </h3>
                            <div className="flex gap-2">
                                <button
                                    onClick={() => showLogs(selectedLogs.name)}
                                    className="p-1.5 hover:bg-slate-200 dark:hover:bg-slate-700 rounded transition"
                                >
                                    <RefreshCw className={`w-4 h-4 text-slate-500 ${logLoading ? 'animate-spin' : ''}`} />
                                </button>
                                <button
                                    onClick={() => setSelectedLogs(null)}
                                    className="p-1.5 hover:bg-red-100 dark:hover:bg-red-900/30 text-red-500 rounded transition"
                                >
                                    ✕
                                </button>
                            </div>
                        </div>

                        <div className="flex-1 overflow-auto p-4 bg-slate-900 text-slate-200 font-mono text-xs md:text-sm whitespace-pre-wrap rounded-b-xl scrollbar-thin">
                            {selectedLogs.content || <span className="text-slate-500 italic">No logs found.</span>}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AdminPanel;
