import { PublicPage } from '@/components/PublicPage';

export default function Terms() {
  return (
    <PublicPage eyebrow="Terms" title="The short version.">
      <p>
        By using Skintel you agree to these terms. They're short on purpose. If anything is
        unclear, email us before signing up.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">What Skintel is</h2>
      <p>
        Skintel is a personal ingredient-tracking tool. It is not a medical device, not a
        substitute for a dermatologist, and not a diagnostic service. Pattern detection is
        statistical — it surfaces correlations from products you tag, not causation.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Your account</h2>
      <p>
        You're responsible for keeping your sign-in credentials secure. You must be at least 13
        years old. One account per person.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Billing</h2>
      <p>
        Pro plans renew monthly or yearly via Stripe. You can cancel anytime from Settings; access
        continues until the end of the current billing period. We don't issue refunds for partial
        periods.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Acceptable use</h2>
      <p>
        Don't scrape, abuse the API, upload images of other people without consent, or use the
        service to defame products or brands. We may suspend accounts that do.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">No warranty</h2>
      <p>
        Skintel is provided "as is". We work hard to keep it accurate and online, but we don't
        guarantee specific outcomes or zero downtime. Use it as a tool, not a prescription.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Changes</h2>
      <p>
        We may update these terms. Significant changes will be announced by email at least 14 days
        in advance.
      </p>

      <p className="text-sm text-muted pt-6">Last updated: {new Date().toLocaleDateString()}</p>
    </PublicPage>
  );
}
