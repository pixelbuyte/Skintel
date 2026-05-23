import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#FAF8F5',
        card: '#FFFEFA',
        primary: '#A35848',
        'primary-hover': '#8E4538',
        ink: '#1A1814',
        muted: '#6B6760',
        border: '#EAE6DF',
        'good-bg': '#E8F5E2',
        'good-fg': '#2D6A2E',
        'bad-bg': '#FDEAEA',
        'bad-fg': '#B22B2B',
        'unsure-bg': '#FFF4E0',
        'unsure-fg': '#8B6914',
      },
      fontFamily: {
        display: ['"Instrument Serif"', 'Georgia', 'serif'],
        sans: ['"DM Sans"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'monospace'],
      },
      borderRadius: {
        card: '16px',
      },
      boxShadow: {
        card: '0 1px 2px rgba(26,24,20,0.04), 0 1px 3px rgba(26,24,20,0.06)',
        soft: '0 4px 12px rgba(26,24,20,0.06)',
        sheet: '0 -12px 32px rgba(26,24,20,0.12)',
      },
      transitionTimingFunction: {
        ios: 'cubic-bezier(0.32, 0.72, 0, 1)',
        emil: 'cubic-bezier(0.23, 1, 0.32, 1)',
      },
      keyframes: {
        'rise-in': {
          '0%': { opacity: '0', transform: 'translateY(12px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        breathe: {
          '0%,100%': { opacity: '0.55', transform: 'scale(1)' },
          '50%': { opacity: '1', transform: 'scale(1.25)' },
        },
        'soft-pulse': {
          '0%,100%': { opacity: '1' },
          '50%': { opacity: '0.6' },
        },
        marquee: {
          '0%': { transform: 'translateX(0)' },
          '100%': { transform: 'translateX(-33.3333%)' },
        },
      },
      animation: {
        'rise-in': 'rise-in 600ms cubic-bezier(0.23, 1, 0.32, 1) both',
        breathe: 'breathe 2400ms ease-in-out infinite',
        'soft-pulse': 'soft-pulse 2200ms ease-in-out infinite',
        marquee: 'marquee 42s linear infinite',
      },
    },
  },
  plugins: [],
} satisfies Config;
