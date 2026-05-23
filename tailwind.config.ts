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
      },
    },
  },
  plugins: [],
} satisfies Config;
