import React, { useState } from 'react';
import { Lock } from 'lucide-react';

interface AdminLoginProps {
    onLogin: (success: boolean) => void;
}

const AdminLogin: React.FC<AdminLoginProps> = ({ onLogin }) => {
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState(false);

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        // Updated credentials
        if (username === 'furkan@kaphaber.com' && password === 'furkan2626') {
            setError(false);
            onLogin(true);
        } else {
            setError(true);
            setPassword('');
            onLogin(false);
        }
    };

    return (
        <div className="flex flex-col items-center justify-center min-h-[50vh] p-4">
            <div className="bg-white dark:bg-slate-800 p-8 rounded-lg shadow-lg w-full max-w-md border border-slate-200 dark:border-slate-700">
                <div className="flex flex-col items-center mb-6">
                    <div className="p-3 bg-indigo-100 dark:bg-indigo-900 rounded-full mb-4">
                        <Lock className="w-8 h-8 text-indigo-600 dark:text-indigo-400" />
                    </div>
                    <h2 className="text-2xl font-bold text-slate-900 dark:text-white">Admin Girişi</h2>
                    <p className="text-slate-500 dark:text-slate-400 mt-2">Devam etmek için giriş yapın</p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                            Kullanıcı Adı
                        </label>
                        <input
                            type="email"
                            value={username}
                            onChange={(e) => setUsername(e.target.value)}
                            className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 outline-none transition-colors"
                            placeholder="ornek@domain.com"
                        />
                    </div>
                    <div>
                        <label className="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1">
                            Şifre
                        </label>
                        <input
                            type="password"
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            className="w-full px-4 py-2 rounded-lg border border-slate-300 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 outline-none transition-colors"
                            placeholder="••••••••"
                        />
                    </div>

                    {error && (
                        <div className="text-red-500 text-sm text-center font-medium bg-red-50 dark:bg-red-900/20 p-2 rounded">
                            Hatalı kullanıcı adı veya şifre
                        </div>
                    )}

                    <button
                        type="submit"
                        className="w-full py-2 px-4 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-lg shadow-md transition-colors focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:focus:ring-offset-slate-900"
                    >
                        Giriş Yap
                    </button>
                </form>
            </div>
        </div>
    );
};

export default AdminLogin;
