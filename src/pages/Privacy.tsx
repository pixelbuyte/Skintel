import { PublicPage } from '@/components/PublicPage';

const LAST_UPDATED = 'September 17, 2026';

export default function Privacy() {
  return (
    <PublicPage eyebrow="Privacy" title="Your data, your business.">
      <p>
        Skintel exists to help you figure out what your skin doesn't like. To do that we store the
        products you log, the ingredients you paste or scan, the outcomes you tag, and the journal
        entries you write. That's it.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">What we collect</h2>
      <p>
        An email (for sign-in), products you add, ingredient lists and product-label photos you
        paste or scan, breakout tags, journal notes, and routine entries. If you scan a product's
        packaging, that photo is sent for one-time processing (see below) and is not stored
        afterward. We don't ask for your full name, address, phone number, or date of birth. We
        never collect health diagnoses.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Who processes your data</h2>
      <p>
        We use a small number of providers to run Skintel, and we don't let any of them use your
        data for anything but serving you:
      </p>
      <ul className="list-disc pl-5 space-y-1">
        <li><strong>Supabase</strong> — our database and sign-in system (hosted in the US).</li>
        <li><strong>Vercel</strong> — hosts the app and API; sees standard request/IP logs like any web host.</li>
        <li>
          <strong>Anthropic</strong> — when you scan a product, the label photo and/or ingredient
          text is sent to Anthropic's API to read and structure it, under Anthropic's commercial
          API terms, which exclude your data from model training. We don't send your name or
          account info with it.
        </li>
        <li>
          <strong>Stripe</strong> (web) or <strong>Apple</strong> (iOS) — process subscription
          payments. We never see or store your full card number; Stripe/Apple handle billing
          directly and share back only your subscription status.
        </li>
      </ul>
      <p>
        We don't sell your data, share it with skincare brands or advertisers, or use it to train
        any public model.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Row-level security</h2>
      <p>
        Every row in our Postgres database is locked to your user ID. Other users — and our own
        backend code without your token — cannot read your products, journal, or routine.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Data retention</h2>
      <p>
        We keep your data for as long as your account is active. If you delete your account, your
        records are removed immediately and purged from backups within 30 days.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Export and delete</h2>
      <p>
        From Settings you can export your entire dataset as JSON or delete your account. Deletion
        is immediate and irreversible. We don't keep shadow copies.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Your rights</h2>
      <p>
        Wherever you're located, you can ask us to access, correct, export, or delete your
        personal data at any time — email us and we'll handle it, usually the same day. If you're
        in the EU/UK, you also have the right to lodge a complaint with your local data protection
        authority.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Children</h2>
      <p>
        Skintel isn't directed at children, and we don't knowingly collect data from anyone under
        13. If you believe a child has created an account, email us and we'll delete it.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Cookies &amp; analytics</h2>
      <p>
        On the web we use one cookie — your Supabase auth session — plus Vercel Analytics, which
        reports aggregated page-view counts and doesn't use cookies or track you across sites. The
        iOS app has no third-party analytics SDK at all; product events are logged locally on your
        device only.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Questions</h2>
      <p>
        Email{' '}
        <a href="mailto:hello@skintel.app" className="text-primary underline-offset-4 hover:underline">
          hello@skintel.app
        </a>
        . We answer.
      </p>

      <p className="text-sm text-muted pt-6">Last updated: {LAST_UPDATED}</p>
    </PublicPage>
  );
}
