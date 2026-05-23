import { PublicPage } from '@/components/PublicPage';

export default function Privacy() {
  return (
    <PublicPage eyebrow="Privacy" title="Your data, your business.">
      <p>
        Skintel exists to help you figure out what your skin doesn't like. To do that we store the
        products you log, the ingredients you paste, the outcomes you tag, and the journal entries
        you write. That's it.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">What we collect</h2>
      <p>
        An email (for sign-in), products you add, ingredient lists you paste or scan, breakout
        tags, journal notes, and routine entries. We don't ask for your full name, address, phone
        number, or date of birth. We never collect health diagnoses.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">What we don't do</h2>
      <p>
        We don't sell your data. We don't share it with brands. We don't train public models on
        your routine. Ingredient analysis runs through Anthropic's API under their no-training
        agreement, and we send only the ingredient text — not who you are.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Row-level security</h2>
      <p>
        Every row in our Postgres database is locked to your user ID. Other users — and our own
        backend code without your token — cannot read your products, journal, or routine.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Export and delete</h2>
      <p>
        From Settings you can export your entire dataset as JSON or delete your account. Deletion
        is immediate and irreversible. We don't keep shadow copies.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Cookies</h2>
      <p>
        We use one cookie: your Supabase auth session. No tracking pixels, no analytics third
        parties.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Questions</h2>
      <p>
        Email{' '}
        <a href="mailto:hello@skintel.app" className="text-primary underline-offset-4 hover:underline">
          hello@skintel.app
        </a>
        . We answer.
      </p>

      <p className="text-sm text-muted pt-6">Last updated: {new Date().toLocaleDateString()}</p>
    </PublicPage>
  );
}
