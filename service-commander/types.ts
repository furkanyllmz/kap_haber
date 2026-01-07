export interface ServiceInfo {
    name: string;
    status: 'running' | 'stopped' | 'unknown';
    pid: number | null;
}

export interface LogData {
    name: string;
    lines: number;
    content: string;
}

export interface ServiceMeta {
    label: string;
    desc: string;
}

export const PYTHON_API_URL = "http://localhost:8000";

export const SERVICE_METADATA: Record<string, ServiceMeta> = {
    pipeline: { label: 'Daily Pipeline', desc: 'Main automation orchestration pipeline' },
    analyzer: { label: 'News Analyzer', desc: 'NLP processing for raw news items' },
    twitterbot: { label: 'Twitter Bot', desc: 'Automated social media publishing agent' },
    financials: { label: 'Fetch Financials', desc: 'Financial data scraping service' },
    fetch_symbols: { label: 'Fetch Symbols', desc: 'Ticker symbol synchronization' },
    extract_logos: { label: 'Logo Extractor', desc: 'Asset download and management' },
};