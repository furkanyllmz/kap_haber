import React from 'react';
import { Play, Square, FileText, Cpu } from 'lucide-react';
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
        <div className="bg-white rounded-xl border border-slate-200 shadow-sm hover:shadow-lg transition-all duration-300 overflow-hidden flex flex-col group">
            <div className="p-5 flex-1">
                <div className="flex justify-between items-start mb-4">
                    <div className="flex items-center gap-3">
                        <div className="relative">
                            <div className={`w-10 h-10 rounded-lg flex items-center justify-center ${isRunning ? 'bg-indigo-50 text-indigo-600' : 'bg-slate-100 text-slate-500'}`}>
                                <Cpu className="w-5 h-5" />
                            </div>
                            {isRunning && (
                                <span className="absolute -top-1 -right-1 flex h-3 w-3">
                                  <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75"></span>
                                  <span className="relative inline-flex rounded-full h-3 w-3 bg-green-500 border-2 border-white"></span>
                                </span>
                            )}
                        </div>
                        <div>
                            <h3 className="font-bold text-slate-900 leading-tight">{meta.label}</h3>
                            <div className="flex items-center gap-2 mt-1">
                                <span className={`text-[10px] uppercase tracking-wider font-bold px-1.5 py-0.5 rounded-sm ${isRunning ? 'bg-green-100 text-green-700' : 'bg-slate-100 text-slate-500'}`}>
                                    {service.status}
                                </span>
                                {isRunning && service.pid && (
                                    <span className="text-[10px] font-mono text-slate-400">PID: {service.pid}</span>
                                )}
                            </div>
                        </div>
                    </div>
                </div>

                <p className="text-sm text-slate-500 leading-relaxed mb-4">
                    {meta.desc}
                </p>
            </div>

            <div className="bg-slate-50 px-5 py-3 border-t border-slate-100 flex items-center gap-2">
                {!isRunning ? (
                    <button
                        onClick={() => onAction(service.name, 'start')}
                        disabled={isProcessing}
                        className="flex-1 flex items-center justify-center gap-2 py-2 bg-white border border-slate-200 text-slate-700 rounded-lg hover:bg-green-50 hover:text-green-700 hover:border-green-200 transition-all text-sm font-medium shadow-sm disabled:opacity-50"
                    >
                        <Play className="w-4 h-4 fill-current" /> Start
                    </button>
                ) : (
                    <button
                        onClick={() => onAction(service.name, 'stop')}
                        disabled={isProcessing}
                        className="flex-1 flex items-center justify-center gap-2 py-2 bg-white border border-slate-200 text-slate-700 rounded-lg hover:bg-red-50 hover:text-red-700 hover:border-red-200 transition-all text-sm font-medium shadow-sm disabled:opacity-50"
                    >
                        <Square className="w-4 h-4 fill-current" /> Stop
                    </button>
                )}

                <button
                    onClick={() => onViewLogs(service.name)}
                    className="p-2 bg-white border border-slate-200 text-slate-500 rounded-lg hover:bg-indigo-50 hover:text-indigo-600 hover:border-indigo-200 transition-all shadow-sm group-hover:border-indigo-200"
                    title="View Logs"
                >
                    <FileText className="w-4 h-4" />
                </button>
            </div>
        </div>
    );
};

export default ServiceCard;