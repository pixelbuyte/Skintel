import { PublicPage } from '@/components/PublicPage';

const LAST_UPDATED = 'September 17, 2026';

function H2({ children }: { children: React.ReactNode }) {
  return <h2 className="font-display text-2xl mt-10 mb-2">{children}</h2>;
}

function H3({ children }: { children: React.ReactNode }) {
  return <h3 className="font-display text-lg mt-5 mb-1">{children}</h3>;
}

export default function Privacy() {
  return (
    <PublicPage eyebrow="Privacy" title="Your data, your business.">
      <p className="text-sm text-muted">Last updated: {LAST_UPDATED}</p>

      <p>
        Skintel ("Skintel," "we," "us," or "our") builds a web app and native iOS app that help you
        figure out which ingredient in your routine is causing a breakout. This policy explains, in
        full, what personal data we collect across the website (skinstel.com), the iOS app, and the
        API that powers both; why we collect it; who we share it with; how long we keep it; and the
        rights you have over it. We wrote the short version first and got told, fairly, that it
        wasn't enough — so here is the long one, and every claim in it is checked against the actual
        code that runs the product rather than boilerplate copied from somewhere else.
      </p>
      <p>
        If anything here is unclear, or you want a plain-English answer to a specific question
        instead of reading the whole thing, email{' '}
        <a href="mailto:hello@skinstel.com" className="text-primary underline-offset-4 hover:underline">
          hello@skinstel.com
        </a>{' '}
        and we'll answer personally — not with a form letter.
      </p>

      <H2>1. Who we are</H2>
      <p>
        Skintel is the data controller for the personal data described in this policy — the entity
        that decides why and how it's processed. This policy covers three surfaces that all talk to
        the same backend and database: the marketing/web app at skinstel.com, the native iOS app
        (bundle id <code>com.skintel.app</code>), and the API routes both of them call. It does not
        cover third-party sites we merely link to (see Section 12).
      </p>

      <H2>2. Information we collect</H2>
      <p>We collect four kinds of information, and nothing beyond them:</p>

      <H3>2.1 Account information</H3>
      <p>
        Just an email address, used for sign-in and account recovery. Sign-in is handled either by
        email + password or Sign In with Apple (iOS only); we do not ask for your full legal name,
        home address, phone number, or date of birth anywhere in the product, and we have no field
        that stores them.
      </p>

      <H3>2.2 Content you create</H3>
      <ul className="list-disc pl-5 space-y-1">
        <li>Products you add to your shelf (brand, product name, and how you found them).</li>
        <li>
          Ingredient lists — either pasted as text, scanned via barcode lookup, or scanned as a
          photo of the product's packaging (see Section 3 for what happens to that photo).
        </li>
        <li>Breakout/outcome tags you attach to a product ("worked," "unsure," "broke out").</li>
        <li>Journal entries and routine entries (AM/PM steps) you write or build.</li>
      </ul>
      <p>
        This content is the entire reason Skintel exists, and it's also the most sensitive data we
        hold. We do not collect medical or health-diagnosis data — a "breakout" tag is your own
        subjective label on a product, not a clinical record, and we do not ask about or store any
        skin condition, diagnosis, or medication.
      </p>

      <H3>2.3 Payment information</H3>
      <p>
        If you subscribe to Pro, payment is handled entirely by Stripe (on the web) or Apple's
        StoreKit/App Store (on iOS). We never see, receive, or store your full card number, card
        expiry, CVV, or Apple ID password. What we store on our side is limited to: which plan
        you're on, its status (active, canceled, etc.), and an opaque customer/subscription
        identifier from Stripe or Apple used to reconcile your entitlement — see the{' '}
        <code>subscriptions</code> table referenced in Section 5.
      </p>

      <H3>2.4 Information collected automatically</H3>
      <p>
        Our hosting provider, Vercel, logs standard request metadata for every request to
        skinstel.com and its API — things like IP address, timestamp, and requested path — the way
        essentially every web server on the internet does, for security and abuse prevention. We do
        not layer any additional device fingerprinting, ad identifiers, or cross-site tracking on
        top of this. See Section 8 for analytics specifically.
      </p>

      <H3>2.5 What we deliberately do not collect</H3>
      <ul className="list-disc pl-5 space-y-1">
        <li>Full legal name, home address, or phone number.</li>
        <li>Date of birth (beyond the age confirmation described in Section 10).</li>
        <li>Medical records, health diagnoses, or insurance information.</li>
        <li>Precise geolocation.</li>
        <li>Photos of your face or skin — the camera is used only to photograph product packaging.</li>
        <li>Advertising identifiers (IDFA) or any data used to build an ad profile.</li>
      </ul>

      <H2>3. How ingredient and photo scanning works</H2>
      <p>
        When you scan a product's barcode, we look it up against a product database and our own
        cache. When you scan a photo of a product's packaging instead — because the barcode is
        missing or unreadable — that photo is sent to Anthropic's API, which reads the label and
        returns the brand, product name, and ingredient list as structured text. The photo itself is
        not stored by Skintel after that request completes; only the resulting text (the ingredient
        list) is saved to your account, the same as if you'd pasted it in yourself. Anthropic
        processes this under its commercial API terms, which exclude API inputs from being used to
        train their models, and we do not attach your name, email, or account identifier to the
        image or text we send.
      </p>

      <H2>4. How we use your information</H2>
      <p>We use what we collect only to:</p>
      <ul className="list-disc pl-5 space-y-1">
        <li>Run the core product — store your shelf, run ingredient cross-referencing, and surface which ingredient correlates with your tagged outcomes.</li>
        <li>Authenticate you and keep your account secure.</li>
        <li>Process and reconcile subscription payments and entitlements.</li>
        <li>Respond to support requests you send us.</li>
        <li>Maintain and secure the service — debugging, abuse prevention, and reliability.</li>
        <li>Meet legal obligations where applicable (e.g. responding to a valid legal request).</li>
      </ul>
      <p>
        We do not use your data for interest-based advertising, we do not build a profile of you to
        sell or license, and we do not use your routine or journal content to train any
        publicly-released model.
      </p>

      <H2>5. Automated processing — what it is and isn't</H2>
      <p>
        Skintel's "verdicts," culprit detection, and routine-conflict warnings are generated by a
        mix of rule-based ingredient logic and, for photo scans, Anthropic's API for OCR/label
        reading as described in Section 3. None of this is used to make — or feed into — any legal
        or similarly significant automated decision about you (for example, nothing related to
        credit, employment, insurance, or access to essential services). It is informational
        skincare guidance based on ingredient data and the outcomes you choose to tag, not medical
        advice, and not a diagnosis.
      </p>

      <H2>6. Legal bases for processing (EU/UK/EEA users)</H2>
      <p>If you're in the EU, UK, or EEA, we rely on the following legal bases under GDPR:</p>
      <ul className="list-disc pl-5 space-y-1">
        <li><strong>Performance of a contract</strong> — processing your account and content data to actually run the service you signed up for.</li>
        <li><strong>Legitimate interests</strong> — for security logging, abuse prevention, and aggregated, non-invasive analytics (Section 8), balanced against your rights.</li>
        <li><strong>Consent</strong> — for anything not covered above, which we'd ask for explicitly before collecting.</li>
        <li><strong>Legal obligation</strong> — where we're required to retain or disclose information by law.</li>
      </ul>

      <H2>7. Who we share information with</H2>
      <p>
        We do not sell your personal data, and we do not share it with skincare brands, retailers,
        or advertisers. We share data only with the service providers ("subprocessors") that run
        the product on our behalf, each bound to use it only to provide their service to us:
      </p>
      <ul className="list-disc pl-5 space-y-1">
        <li><strong>Supabase</strong> — our database and authentication provider. Your account data and content live here, in a Postgres database hosted in the United States (see Section 9 on international transfers), protected by row-level security (Section 9).</li>
        <li><strong>Vercel</strong> — hosts the web app and all API routes, and provides the standard request logging described in Section 2.4 and the aggregated analytics described in Section 8.</li>
        <li><strong>Anthropic</strong> — processes ingredient text and, for photo scans, the packaging photo, as described in Section 3.</li>
        <li><strong>Stripe</strong> — processes web subscription payments and holds your payment method on our behalf; we receive back only subscription status and identifiers, never full card details.</li>
        <li><strong>Apple</strong> — processes iOS subscription payments through the App Store/StoreKit; we receive back a signed transaction we verify server-side, never your Apple ID credentials or card details.</li>
      </ul>
      <p>
        Beyond these, we would disclose information only if required to comply with a valid legal
        process (such as a subpoena or court order), to enforce our terms, to protect the rights,
        property, or safety of Skintel, our users, or the public, or in connection with a merger,
        acquisition, or sale of assets — in which case this policy would continue to apply to your
        data under the new ownership until you're notified of any change.
      </p>

      <H2>8. Cookies and analytics</H2>
      <p>
        On the web app, we set exactly one cookie: your Supabase authentication session, which
        keeps you signed in. We also use Vercel Analytics, which reports aggregated, anonymous
        page-view counts to us — it does not use cookies, does not track you across other sites, and
        does not build any individual profile. We do not use Google Analytics, Meta/Facebook Pixel,
        or any other third-party advertising or tracking script. The iOS app has no third-party
        analytics SDK at all — product events (like "scan started" or "purchase completed") are
        logged locally to your device's system log only, and never leave the device; see{' '}
        <code>Analytics.swift</code> in the app's source if you want to verify this yourself.
      </p>
      <p>
        Because we don't do cross-site tracking in the first place, we don't currently render a
        distinct response to browser "Do Not Track" signals — there is no additional tracking for
        such a signal to turn off.
      </p>

      <H2>9. Security and international transfers</H2>
      <p>
        All traffic to skinstel.com and the app is encrypted in transit (HTTPS/TLS), and encrypted
        at rest in Supabase's underlying storage. Every row in our Postgres database is locked to
        your user ID with row-level security policies — the ordinary product API, running under
        your access token, cannot read another user's products, journal, ingredients, or routine.
        Passwords are never stored in plain text; they are hashed by Supabase's authentication
        system.
      </p>
      <H3>9.1 Administrative access</H3>
      <p>
        Row-level security governs the app's ordinary API surface. A small number of privileged
        server routes — account export and deletion, and writing subscription status after a
        payment is verified — necessarily run with elevated database access that is not scoped to
        a single user, because that's what those operations require. This access exists only in
        those specific, code-reviewable server routes, is used only to perform the exact action you
        requested (export, delete, apply an entitlement) or to investigate a support request or
        abuse report, and is never used to browse or read your content out of curiosity. We're
        naming this plainly rather than implying row-level security is an absolute technical wall
        with no administrative access at all, which wouldn't be accurate.
      </p>
      <p>
        Our infrastructure (Supabase's database, Vercel's hosting, Anthropic's API) is based in the
        United States. If you're accessing Skintel from the EU, UK, or elsewhere outside the US,
        your data will be transferred to and processed in the US under each provider's own standard
        data processing terms, which incorporate the EU Standard Contractual Clauses for exactly
        this kind of transfer. By using Skintel, you understand that your information will be
        processed in the United States, which may have different data protection laws than your
        home country.
      </p>

      <H2>10. Children's privacy</H2>
      <p>
        Skintel is not directed at children and is not intended for use by anyone under 13. We do
        not knowingly collect personal information from children under 13, and if we learn that we
        have, we will delete it promptly. If you believe a child has created an account, email us at{' '}
        <a href="mailto:hello@skinstel.com" className="text-primary underline-offset-4 hover:underline">
          hello@skinstel.com
        </a>{' '}
        and we will remove it.
      </p>

      <H2>11. Data retention and deletion</H2>
      <p>
        We keep your account and content for as long as your account is active, plus a short window
        after deletion described below. From Settings, you can at any time:
      </p>
      <ul className="list-disc pl-5 space-y-1">
        <li><strong>Export</strong> your entire dataset — every product, ingredient list, and your subscription record — as a downloadable JSON file.</li>
        <li>
          <strong>Delete your account</strong>, which immediately and permanently removes your
          subscription record and every product/ingredient row tied to your account, then deletes
          your authentication record entirely. This is irreversible — we do not keep a shadow copy
          or "soft delete" your account.
        </li>
      </ul>
      <p>
        Because deletion happens directly against the live database rather than a queued job,
        removal from primary storage is immediate. Routine infrastructure backups that were taken
        before your deletion may persist for up to 30 days before they, too, roll off, purely as an
        artifact of standard backup retention, not because we keep a separate record of you.
      </p>

      <H2>12. Third-party links</H2>
      <p>
        Skintel links out to a small number of external destinations — for example, App Store /
        Google Play badges, and a "search to buy" link that opens a Google search for a product
        you're viewing. These are ordinary outbound links: clicking them takes you to a third
        party's site, which is governed by that site's own privacy policy, not this one. We don't
        pass any of your Skintel account data to these destinations when you click through.
      </p>

      <H2>13. Your rights and choices</H2>
      <p>
        Regardless of where you live, you can ask us at any time to access, correct, export, or
        delete your personal data — most of this you can already do yourself from Settings, and
        anything else, email us and we'll handle it personally, usually the same day.
      </p>
      <H3>13.1 EU / UK / EEA — GDPR rights</H3>
      <p>You have the right to:</p>
      <ul className="list-disc pl-5 space-y-1">
        <li>Access the personal data we hold about you.</li>
        <li>Rectify inaccurate data.</li>
        <li>Erase your data ("right to be forgotten").</li>
        <li>Restrict or object to certain processing.</li>
        <li>Receive your data in a portable format (our JSON export).</li>
        <li>Withdraw consent at any time, where processing is based on consent.</li>
        <li>Lodge a complaint with your local data protection supervisory authority.</li>
      </ul>
      <H3>13.2 California — CCPA/CPRA rights</H3>
      <p>If you're a California resident, you have the right to:</p>
      <ul className="list-disc pl-5 space-y-1">
        <li>Know what personal information we collect, use, and disclose, as described in this policy.</li>
        <li>Delete your personal information.</li>
        <li>Correct inaccurate personal information.</li>
        <li>Opt out of the "sale" or "sharing" of personal information — we don't sell or share personal information as defined by the CCPA/CPRA, so there is nothing to opt out of.</li>
        <li>Not be discriminated against for exercising any of these rights.</li>
      </ul>
      <p>
        To exercise any right in this section, email{' '}
        <a href="mailto:hello@skinstel.com" className="text-primary underline-offset-4 hover:underline">
          hello@skinstel.com
        </a>
        . We may need to verify it's really you (typically by confirming from the email address on
        your account) before acting on the request.
      </p>

      <H2>14. Changes to this policy</H2>
      <p>
        If we make a material change to how we collect or use your data, we'll update the date at
        the top of this page and, where the change is significant, notify you by email or an in-app
        notice before it takes effect. Minor clarifications (like this rewrite) are reflected here
        without separate notice.
      </p>

      <H2>15. Contact us</H2>
      <p>
        Questions, requests, or concerns about this policy or your data: email{' '}
        <a href="mailto:hello@skinstel.com" className="text-primary underline-offset-4 hover:underline">
          hello@skinstel.com
        </a>
        . We answer.
      </p>

      <p className="text-sm text-muted pt-6">Last updated: {LAST_UPDATED}</p>
    </PublicPage>
  );
}
