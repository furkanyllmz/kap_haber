import React, { useState, useEffect } from 'react';
import { Activity, RefreshCw, Server, ShieldCheck } from './Icons';
import { ServiceInfo, PYTHON_API_URL } from '../types';
import ServiceCard from './ServiceCard';
import LogTerminal from './LogTerminal';

const MOCK_SERVICES: ServiceInfo[] = [
    { name: 'pipeline', status: 'running', pid: 14023 },
    { name: 'analyzer', status: 'running', pid: 14055 },
    { name: 'twitterbot', status: 'stopped', pid: null },
    { name: 'financials', status: 'running', pid: 15100 },
    { name: 'fetch_symbols', status: 'stopped', pid: null },
    { name: 'extract_logos', status: 'unknown', pid: null },
];

const AdminPanel: React.FC = () => {
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

    // --- Scheduler Logic ---
    const [schedule, setSchedule] = useState<{ hour: number, minute: number } | null>(null);
    const [scheduleLoading, setScheduleLoading] = useState(false);

    const fetchSchedule = async () => {
        try {
            const res = await fetch(`${PYTHON_API_URL}/scheduler/jobs/daily_summary_job`);
            if (res.ok) {
                const data = await res.json();
                setSchedule({ hour: data.hour, minute: data.minute });
            }
        } catch (err) {
            console.error("Failed to fetch schedule:", err);
        }
    };

    const updateSchedule = async () => {
        if (!schedule) return;
        setScheduleLoading(true);
        try {
            const res = await fetch(`${PYTHON_API_URL}/scheduler/jobs/daily_summary_job`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(schedule)
            });
            if (res.ok) {
                alert("Zamanlama güncellendi!");
            } else {
                throw new Error("Update failed");
            }
        } catch (err) {
            alert("Güncelleme başarısız: " + err);
        } finally {
            setScheduleLoading(false);
        }
    };

    const triggerManualSummary = async () => {
        if (!confirm("Günlük özeti şimdi oluşturmak istiyor musunuz?")) return;
        try {
            const res = await fetch(`${PYTHON_API_URL}/summary/generate`, { method: 'POST' });
            if (res.ok) alert("Özet oluşturma başlatıldı.");
        } catch (err) {
            alert("Hata: " + err);
        }
    };

    useEffect(() => {
        fetchSchedule();
    }, []);

    return (
        <div className="min-h-screen bg-slate-50 dark:bg-market-bg text-slate-900 pb-20">
            {/* Header / Navbar */}
            <header className="bg-white dark:bg-market-card border-b border-slate-200 dark:border-slate-800 sticky top-0 z-10 transition-colors">
                <div className="max-w-6xl mx-auto px-4 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <div className="bg-indigo-600 p-2 rounded-lg text-white">
                            <ShieldCheck className="w-6 h-6" />
                        </div>
                        <div>
                            <h1 className="text-xl font-bold tracking-tight text-slate-900 dark:text-white">Service Commander</h1>
                            <div className="flex items-center gap-2 text-xs text-slate-500 dark:text-slate-400">
                                <span className="w-2 h-2 rounded-full bg-green-500 shadow-[0_0_8px_rgba(34,197,94,0.6)]"></span>
                                Sistem Çevrimiçi
                            </div>
                        </div>
                    </div>

                    <div className="flex items-center gap-4">
                        <div className="hidden sm:flex items-center gap-4 px-4 py-1.5 bg-slate-100 dark:bg-slate-800 rounded-full border border-slate-200 dark:border-slate-700 text-sm font-medium text-slate-600 dark:text-slate-300">
                            <div className="flex items-center gap-2">
                                <Server className="w-4 h-4 text-slate-400" />
                                <span>Toplam: <span className="text-slate-900 dark:text-white">{services.length}</span></span>
                            </div>
                            <div className="w-[1px] h-4 bg-slate-300 dark:bg-slate-600"></div>
                            <div className="flex items-center gap-2">
                                <Activity className="w-4 h-4 text-green-500" />
                                <span>Çalışan: <span className="text-slate-900 dark:text-white">{activeServicesCount}</span></span>
                            </div>
                        </div>

                        <button
                            onClick={() => { fetchServices(); fetchSchedule(); }}
                            disabled={loading}
                            className={`p-2 rounded-full hover:bg-slate-100 dark:hover:bg-slate-800 border border-transparent hover:border-slate-200 dark:hover:border-slate-700 transition-all ${loading ? 'text-indigo-600 dark:text-indigo-400' : 'text-slate-500 dark:text-slate-400'}`}
                            title="Verileri Yenile"
                        >
                            <RefreshCw className={`w-5 h-5 ${loading ? 'animate-spin' : ''}`} />
                        </button>
                    </div>
                </div>
            </header>

            {/* Main Content */}
            <main className="max-w-6xl mx-auto px-4 py-8 space-y-8">

                {/* Scheduled Jobs Section */}
                <section>
                    <div className="flex items-center gap-2 mb-4">
                        <h2 className="text-lg font-semibold text-slate-900 dark:text-white">Zamanlanmış Görevler</h2>
                        <div className="h-[1px] flex-1 bg-slate-200 dark:bg-slate-800"></div>
                    </div>

                    <div className="bg-white dark:bg-market-card rounded-xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm">
                        <div className="flex items-center justify-between flex-wrap gap-4">
                            <div className="flex items-center gap-4">
                                <div className="bg-blue-100 dark:bg-blue-900/30 p-3 rounded-lg text-blue-600 dark:text-blue-400">
                                    <Activity className="w-6 h-6" />
                                </div>
                                <div>
                                    <h3 className="font-medium text-slate-900 dark:text-white">Günlük Özet Oluşturucu</h3>
                                    <p className="text-sm text-slate-500 dark:text-slate-400">Otomatik piyasa özeti ve bildirimler</p>
                                </div>
                            </div>

                            {schedule && (
                                <div className="flex items-center gap-4 bg-slate-50 dark:bg-slate-900/50 p-2 rounded-lg border border-slate-100 dark:border-slate-800">
                                    <div className="flex items-center gap-2">
                                        <label className="text-sm font-medium text-slate-600 dark:text-slate-400">Saat:</label>
                                        <input
                                            type="number"
                                            min="0" max="23"
                                            value={schedule.hour}
                                            onChange={(e) => setSchedule({ ...schedule, hour: parseInt(e.target.value) })}
                                            className="w-16 px-2 py-1 rounded border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-center"
                                        />
                                    </div>
                                    <span className="text-slate-400">:</span>
                                    <div className="flex items-center gap-2">
                                        <label className="text-sm font-medium text-slate-600 dark:text-slate-400">Dakika:</label>
                                        <input
                                            type="number"
                                            min="0" max="59"
                                            value={schedule.minute}
                                            onChange={(e) => setSchedule({ ...schedule, minute: parseInt(e.target.value) })}
                                            className="w-16 px-2 py-1 rounded border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-center"
                                        />
                                    </div>

                                    <div className="w-[1px] h-6 bg-slate-200 dark:bg-slate-700 mx-2"></div>

                                    <button
                                        onClick={updateSchedule}
                                        disabled={scheduleLoading}
                                        className="px-3 py-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-md text-sm font-medium transition-colors disabled:opacity-50"
                                    >
                                        {scheduleLoading ? 'Kaydediliyor...' : 'Kaydet'}
                                    </button>
                                </div>
                            )}

                            <button
                                onClick={triggerManualSummary}
                                className="px-4 py-2 text-sm font-medium text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 transition-colors"
                            >
                                Şimdi Çalıştır
                            </button>
                        </div>
                    </div>
                </section>

                {/* Services Grid */}
                <section>
                    <div className="flex items-center gap-2 mb-4">
                        <h2 className="text-lg font-semibold text-slate-900 dark:text-white">Servis Durumları</h2>
                        <div className="h-[1px] flex-1 bg-slate-200 dark:bg-slate-800"></div>
                    </div>

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
                            <div className="col-span-full py-12 flex flex-col items-center justify-center text-slate-400 dark:text-slate-500 border-2 border-dashed border-slate-200 dark:border-slate-800 rounded-xl bg-slate-50/50 dark:bg-slate-900/20">
                                <Server className="w-12 h-12 mb-4 opacity-50" />
                                <p className="text-lg font-medium text-slate-500 dark:text-slate-400">Servis Bulunamadı</p>
                                <p className="text-sm">Arka uç servisi {PYTHON_API_URL} adresinde çalışıyor mu?</p>
                            </div>
                        )}
                    </div>
                </section>
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

export default AdminPanel;

