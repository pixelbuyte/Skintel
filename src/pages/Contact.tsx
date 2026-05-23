import { PublicPage } from '@/components/PublicPage';
import { Mail, ExternalLink } from 'lucide-react';

export default function Contact() {
  return (
    <PublicPage eyebrow="Contact" title="Get in touch.">
      <p>
        Bug report, feature request, billing question, press inquiry — same inbox. Replies usually
        come within a day.
      </p>

      <div className="flex flex-col sm:flex-row gap-3 pt-2">
        <a
          href="mailto:hello@skintel.app"
          className="btn-primary active:scale-[0.97] transition-transform duration-150 ease-emil"
        >
          <Mail size={16} /> hello@skintel.app
        </a>
        <a
          href="https://github.com/anthropics/claude-code/issues"
          target="_blank"
          rel="noopener noreferrer"
          className="btn-secondary active:scale-[0.97] transition-transform duration-150 ease-emil"
        >
          <ExternalLink size={16} /> Open an issue
        </a>
      </div>

      <p className="text-sm text-muted pt-4">
        For account deletion or data export, you can do both yourself from Settings — no need to
        email.
      </p>
    </PublicPage>
  );
}
