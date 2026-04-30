/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{vue,js,ts,jsx,tsx}'
  ],
  theme: {
    extend: {
      colors: {
        // 霓虹蓝主色
        primary: {
          50:  '#e8f1fc',
          100: '#c5d9f7',
          200: '#9dc0f2',
          300: '#74a6ed',
          400: '#4f8de8',
          500: '#2b74e4',
          600: '#3b82f6',
          700: '#2563eb',
          800: '#1d4ed8',
          900: '#0f1117'
        },
        // 电光橙 accent
        accent: {
          50:  '#fff7ed',
          100: '#ffedd5',
          200: '#fed7aa',
          300: '#fdba74',
          400: '#fb923c',
          500: '#f97316',
          600: '#ea580c',
          700: '#c2410c',
        },
        // 暗色主题背景
        dark: {
          50:  '#f8fafc',
          100: '#f1f5f9',
          200: '#e2e8f0',
          300: '#cbd5e1',
          400: '#94a3b8',
          500: '#64748b',
          600: '#475569',
          700: '#334155',
          800: '#1e293b',
          850: '#1a1d2e',
          900: '#0f1117',
          950: '#090a10'
        },
        court: {
          wood: '#c8860a',
          line: '#ffffff',
          bg:   '#1a1a1a'
        },
        // 语义色
        success: { DEFAULT: '#22c55e', light: '#4ade80', dark: '#16a34a' },
        warning: { DEFAULT: '#eab308', light: '#facc15', dark: '#ca8a04' },
        danger:  { DEFAULT: '#ef4444', light: '#f87171', dark: '#dc2626' },
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', '"Segoe UI"', '"PingFang SC"', '"Hiragino Sans GB"', 'sans-serif']
      },
      screens: {
        xs: '375px'
      },
      animation: {
        'fade-in': 'fadeIn 0.3s ease-out',
        'slide-up': 'slideUp 0.4s ease-out',
        'slide-down': 'slideDown 0.3s ease-out',
        'scale-in': 'scaleIn 0.2s ease-out',
        'glow-pulse': 'glowPulse 2s ease-in-out infinite',
        'float': 'float 3s ease-in-out infinite',
        'shimmer': 'shimmer 1.5s infinite',
        'bounce-in': 'bounceIn 0.5s ease-out',
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0' },
          '100%': { opacity: '1' }
        },
        slideUp: {
          '0%': { opacity: '0', transform: 'translateY(12px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        slideDown: {
          '0%': { opacity: '0', transform: 'translateY(-8px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.95)' },
          '100%': { opacity: '1', transform: 'scale(1)' }
        },
        glowPulse: {
          '0%, 100%': { boxShadow: '0 0 5px rgba(59,130,246,0.3)' },
          '50%': { boxShadow: '0 0 20px rgba(59,130,246,0.6), 0 0 40px rgba(59,130,246,0.2)' }
        },
        float: {
          '0%, 100%': { transform: 'translateY(0)' },
          '50%': { transform: 'translateY(-6px)' }
        },
        shimmer: {
          '0%': { backgroundPosition: '-200% 0' },
          '100%': { backgroundPosition: '200% 0' }
        },
        bounceIn: {
          '0%': { opacity: '0', transform: 'scale(0.3)' },
          '50%': { transform: 'scale(1.05)' },
          '70%': { transform: 'scale(0.9)' },
          '100%': { opacity: '1', transform: 'scale(1)' }
        }
      },
      boxShadow: {
        'neon-blue': '0 0 10px rgba(59,130,246,0.3), 0 0 30px rgba(59,130,246,0.1)',
        'neon-blue-lg': '0 0 15px rgba(59,130,246,0.4), 0 0 45px rgba(59,130,246,0.15)',
        'neon-orange': '0 0 10px rgba(249,115,22,0.3), 0 0 30px rgba(249,115,22,0.1)',
        'neon-green': '0 0 10px rgba(34,197,94,0.3), 0 0 30px rgba(34,197,94,0.1)',
        'glass': '0 8px 32px rgba(0,0,0,0.3)',
        'card': '0 4px 16px rgba(0,0,0,0.2)',
      }
    }
  },
  plugins: [
    require('@tailwindcss/forms')
  ]
}
