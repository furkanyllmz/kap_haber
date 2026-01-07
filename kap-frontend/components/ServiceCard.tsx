import React from 'react';
import { Play, Square, FileText, Cpu } from './Icons';
import { ServiceInfo, SERVICE_METADATA } from '../types';

interface ServiceCardProps {
    service: ServiceInfo;
    onAction: (name: string, action: 'start' | 'stop') => void;
    onViewLogs: (name: string) => void;
    isProcessing: boolean;
}

const ServiceCard: React.FC<ServiceCardProps> = ({ service, onAction, onViewLogs, isProcessing }) => {
    const isRunning = service.status === 'running';
    const meta = SERVICE_METADATA[service.name] || { label: service.name, desc: 'Unknown Service' };

    return (
        <div className="bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 shadow-sm hover:shadow-lg transition-all duration-300 overflow-hidden flex flex-col group">
            <div className="p-5 flex-1">
                <div className="flex justify-between items-start mb-4">
                    <div className="flex items-center gap-3">
                        <div className="relative">
                            <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${isRunning ? 'bg-indigo-50 dark:bg-indigo-900/40 text-indigo-600 dark:text-indigo-400' : 'bg-slate-100 dark:bg-slate-700 text-slate-500 dark:text-slate-400'}`}>
                                <Cpu className="w-5 h-5" />
                            </div>
                            {isRunning && (
                                <span className="absolute -top-1 -right-1 flex h-3 w-3">
                                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                                    <span className="relative inline-flex rounded-full h-3 w-3 bg-green-500 border-2 border-white dark:border-slate-800"></span>
                                </span>
                            )}
                        </div>
                        <div>
                            <h3 className="font-bold text-slate-900 dark:text-white leading-tight">{meta.label}</h3>
                            <div className="flex items-center gap-2 mt-1">
                                <span className={`text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded-sm ${isRunning ? 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400' : 'bg-slate-100 text-slate-500 dark:bg-slate-700 dark:text-slate-400'}`}>
                                    {service.status}
                                </span>
                                {isRunning && service.pid && (
                                    <span className="text-[10px] font-mono text-slate-400 dark:text-slate-500">PID: {service.pid}</span>
                                )}
                            </div>
                        </div>
                    </div>
                </div>

                <p className="text-sm text-slate-500 dark:text-slate-400 leading-relaxed mb-4">
                    {meta.desc}
                </p>
            </div>

            <div className="bg-slate-50 dark:bg-slate-900/50 px-5 py-3 border-t border-slate-100 dark:border-slate-700 flex items-center gap-2">
                {!isRunning ? (
                    <button
                        onClick={() => onAction(service.name, 'start')}
                        disabled={isProcessing}
                        className="flex-1 flex items-center justify-center gap-2 py-2 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 rounded-lg hover:bg-green-50 dark:hover:bg-green-900/20 hover:text-green-700 dark:hover:text-green-400 hover:border-green-200 dark:hover:border-green-900/40 transition-all text-sm font-medium shadow-sm disabled:opacity-50"
                    >
                        <Play className="w-4 h-4 fill-current" /> Başlat
                    </button>
                ) : (
                    <button
                        onClick={() => onAction(service.name, 'stop')}
                        disabled={isProcessing}
                        className="flex-1 flex items-center justify-center gap-2 py-2 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 hover:text-red-700 dark:hover:text-red-400 hover:border-red-200 dark:hover:border-red-900/40 transition-all text-sm font-medium shadow-sm disabled:opacity-50"
                    >
                        <Square className="w-4 h-4 fill-current" /> Durdur
                    </button>
                )}

                <button
                    onClick={() => onViewLogs(service.name)}
                    className="p-2 bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-500 dark:text-slate-400 rounded-lg hover:bg-indigo-50 dark:hover:bg-indigo-900/20 hover:text-indigo-600 dark:hover:text-indigo-400 hover:border-indigo-200 dark:hover:border-indigo-900/40 transition-all shadow-sm group-hover:border-indigo-200 dark:group-hover:border-indigo-900/40"
                    title="Logları Gör"
                >
                    <FileText className="w-4 h-4" />
                </button>
            </div>
        </div>
    );
};

export default ServiceCard;
