import React, { useEffect, useRef, useState, useCallback } from 'react';
import { X, RefreshCw, Pause, Play, Download, Terminal } from './Icons';
import { LogData, PYTHON_API_URL, SERVICE_METADATA } from '../types';

interface LogTerminalProps {
    serviceName: string;
    onClose: () => void;
}

const generateMockLogs = (serviceName: string, count: number) => {
    const lines = [];
    const actions = ['Processing', 'Analyzing', 'Connecting to', 'Fetching data from', 'Saving to DB', 'Heartbeat signal'];
    const levels = ['INFO', 'INFO', 'INFO', 'DEBUG', 'WARNING'];

    for (let i = 0; i < count; i++) {
        const timestamp = new Date(Date.now() - (count - i) * 1000).toISOString().replace('T', ' ').substring(0, 19);
        const level = levels[Math.floor(Math.random() * levels.length)];
        const action = actions[Math.floor(Math.random() * actions.length)];
        lines.push(`[${timestamp}] [${level}] ${action} module in ${serviceName} - task_id:${Math.floor(Math.random() * 9999)}`);
    }
    return lines.join('\n');
};

const LogTerminal: React.FC<LogTerminalProps> = ({ serviceName, onClose }) => {
    const [logs, setLogs] = useState<string>('');
    const [loading, setLoading] = useState<boolean>(true);
    const [autoScroll, setAutoScroll] = useState<boolean>(true);
    const [isPolling, setIsPolling] = useState<boolean>(true);
    const logsEndRef = useRef<HTMLDivElement>(null);
    const containerRef = useRef<HTMLDivElement>(null);

    // Fetch logs function
    const fetchLogs = useCallback(async (isInitial = false) => {
        if (!isInitial && !isPolling) return; // Don't fetch if paused, unless it's initial load

        try {
            const res = await fetch(`${PYTHON_API_URL}/services/${serviceName}/logs?lines=200`);
            if (res.ok) {
                const data: LogData = await res.json();
                setLogs(data.content);
            } else {
                throw new Error("Mock fallback");
            }
        } catch (error) {
            // Mock Log Generation logic for demo
            if (isInitial) {
                setLogs(generateMockLogs(serviceName, 20));
            } else if (isPolling) {
                // Append a new line occasionally to simulate live logs
                const timestamp = new Date().toISOString().replace('T', ' ').substring(0, 19);
                const newLog = `[${timestamp}] [INFO] Real-time update for ${serviceName}: processed item #${Math.floor(Math.random() * 10000)}`;
                setLogs(prev => prev + '\n' + newLog);
            }
        } finally {
            setLoading(false);
        }
    }, [serviceName, isPolling]);

    // Initial load
    useEffect(() => {
        fetchLogs(true);
    }, []); // Only run once on mount

    // Polling interval for "Live" feel
    useEffect(() => {
        let interval: any;
        if (isPolling) {
            interval = setInterval(() => fetchLogs(false), 2000); // Poll every 2 seconds
        }
        return () => clearInterval(interval);
    }, [isPolling, fetchLogs]);

    // Auto-scroll logic
    useEffect(() => {
        if (autoScroll && logsEndRef.current) {
            logsEndRef.current.scrollIntoView({ behavior: 'smooth' });
        }
    }, [logs, autoScroll]);

    // Handle manual scroll to disable auto-scroll
    const handleScroll = () => {
        if (!containerRef.current) return;
        const { scrollTop, scrollHeight, clientHeight } = containerRef.current;
        const isAtBottom = scrollHeight - scrollTop === clientHeight;

        // If user scrolls up, disable auto-scroll. If they hit bottom, re-enable.
        if (isAtBottom) {
            setAutoScroll(true);
        } else {
            setAutoScroll(false);
        }
    };

    const downloadLogs = () => {
        const element = document.createElement("a");
        const file = new Blob([logs], { type: 'text/plain' });
        element.href = URL.createObjectURL(file);
        element.download = `${serviceName}_logs_${new Date().toISOString()}.txt`;
        document.body.appendChild(element);
        element.click();
    };

    const meta = SERVICE_METADATA[serviceName] || { label: serviceName, desc: '' };

    return (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm p-4 animate-in fade-in duration-200">
            <div className="w-full max-w-5xl bg-[#0f172a] rounded-lg shadow-2xl border border-slate-700 flex flex-col h-[85vh] overflow-hidden">

                {/* Terminal Header */}
                <div className="flex items-center justify-between px-4 py-3 bg-slate-800 border-b border-slate-700 select-none">
                    <div className="flex items-center gap-3">
                        <div className="flex gap-1.5">
                            <div className="w-3 h-3 rounded-full bg-red-500 hover:bg-red-600 transition-colors cursor-pointer" onClick={onClose} />
                            <div className="w-3 h-3 rounded-full bg-amber-500 hover:bg-amber-600 transition-colors" />
                            <div className="w-3 h-3 rounded-full bg-green-500 hover:bg-green-600 transition-colors" />
                        </div>
                        <div className="h-4 w-[1px] bg-slate-600 mx-2"></div>
                        <div className="flex items-center gap-2 text-slate-200">
                            <Terminal className="w-4 h-4 text-indigo-400" />
                            <span className="font-mono text-sm font-bold tracking-tight">root@server:~/{meta.label}</span>
                        </div>
                    </div>

                    <div className="flex items-center gap-2">
                        <button
                            onClick={() => setIsPolling(!isPolling)}
                            className={`flex items-center gap-1.5 px-3 py-1 rounded text-xs font-medium transition-colors border ${isPolling ? 'bg-indigo-500/10 border-indigo-500/50 text-indigo-400' : 'bg-slate-700 border-slate-600 text-slate-400'}`}
                        >
                            {isPolling ? <Pause className="w-3 h-3" /> : <Play className="w-3 h-3" />}
                            {isPolling ? 'CANLI' : 'DURAKLATILDI'}
                        </button>

                        <button
                            onClick={() => fetchLogs(true)}
                            className="p-1.5 hover:bg-slate-700 rounded text-slate-400 hover:text-white transition-colors"
                            title="Yenile"
                        >
                            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
                        </button>

                        <button
                            onClick={downloadLogs}
                            className="p-1.5 hover:bg-slate-700 rounded text-slate-400 hover:text-white transition-colors"
                            title="Logları İndir"
                        >
                            <Download className="w-4 h-4" />
                        </button>

                        <div className="h-4 w-[1px] bg-slate-600 mx-1"></div>

                        <button
                            onClick={onClose}
                            className="p-1.5 hover:bg-red-500/20 text-slate-400 hover:text-red-400 rounded transition-colors"
                        >
                            <X className="w-4 h-4" />
                        </button>
                    </div>
                </div>

                {/* Terminal Body */}
                <div
                    ref={containerRef}
                    onScroll={handleScroll}
                    className="flex-1 overflow-y-auto p-4 font-mono text-sm terminal-scrollbar relative custom-scrollbar"
                >
                    {logs ? (
                        <div className="space-y-1">
                            {logs.split('\n').map((line, i) => (
                                <div key={i} className="flex gap-4 group hover:bg-white/5 px-1 rounded-sm">
                                    <span className="text-slate-600 select-none w-8 text-right flex-shrink-0">{i + 1}</span>
                                    <span className="text-slate-300 break-all whitespace-pre-wrap">{line}</span>
                                </div>
                            ))}
                            {/* Dummy element to scroll to */}
                            <div ref={logsEndRef} />
                        </div>
                    ) : (
                        <div className="flex flex-col items-center justify-center h-full text-slate-500 gap-2">
                            {loading ? (
                                <RefreshCw className="w-8 h-8 animate-spin" />
                            ) : (
                                <span>Bu oturum için log kaydı yok.</span>
                            )}
                        </div>
                    )}

                    {/* Floating status for auto-scroll */}
                    {!autoScroll && (
                        <button
                            onClick={() => setAutoScroll(true)}
                            className="absolute bottom-4 right-8 bg-indigo-600 hover:bg-indigo-700 text-white text-xs px-3 py-1.5 rounded-full shadow-lg flex items-center gap-2 animate-in slide-in-from-bottom-2"
                        >
                            <span className="relative flex h-2 w-2">
                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-indigo-200 opacity-75"></span>
                                <span className="relative inline-flex rounded-full h-2 w-2 bg-white"></span>
                            </span>
                            Otomatik Kaydırma
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
};

export default LogTerminal;
