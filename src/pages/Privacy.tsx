import { PublicPage } from '@/components/PublicPage';

const updatedDate = 'September 17, 2026';

export default function Privacy() {
  return (
    <PublicPage eyebrow="Privacy" title="Your data, your business.">
      <p>
        This Privacy Policy explains how Skintel collects, uses, and protects information when you
        use the Skintel website and mobile app. Skintel is a personal skincare organization and
        ingredient-awareness tool. It does not provide medical advice, diagnosis, or treatment.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Information we collect</h2>
      <p>We collect information needed to provide the service, including:</p>
      <ul className="list-disc pl-6 space-y-2">
        <li><strong>Account information:</strong> your email address, account identifier, and name if you provide one through a sign-in method.</li>
        <li><strong>Skincare information you add:</strong> products, brands, ingredient lists, routines, product outcomes, skin-profile preferences, journal entries, and notes.</li>
        <li><strong>Photos you choose to use:</strong> ingredient-label photos for scanning and photos or image links you add to journal entries.</li>
        <li><strong>Purchase information:</strong> subscription status and purchase history needed to provide paid access. Payment-card details are handled by Apple or Stripe and are not stored by Skintel.</li>
        <li><strong>Service and device information:</strong> authentication-session data and limited web usage information generated when you use the website.</li>
      </ul>

      <h2 className="font-display text-2xl mt-8 mb-2">How we use information</h2>
      <p>We use this information to create and secure your account; save your shelf, routines, journal, and product history; scan labels and analyze ingredients and routines; manage subscriptions; provide support; maintain security; and comply with applicable law.</p>

      <h2 className="font-display text-2xl mt-8 mb-2">AI-assisted features</h2>
      <p>
        If you use label scanning, ingredient analysis, routine analysis, or journal analysis, the relevant text and, where needed, the image you submit are sent to Anthropic to provide that feature. We do not send your email address or account identifier as part of the AI prompt. Do not include information in notes or images that you would not want processed to provide the requested feature.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Service providers</h2>
      <p>
        We use service providers that process information for us: Supabase for authentication and database services, Vercel for website hosting and limited web analytics, Anthropic for the AI-assisted features described above, Stripe for web subscription payments, Apple for in-app purchases, and Resend to send service emails. These providers may process data only as needed to provide their services to us and under their applicable terms and policies.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Analytics and tracking</h2>
      <p>
        The website uses Vercel Analytics to understand aggregate website usage. The native iOS app does not include third-party advertising or analytics SDKs. We do not sell personal information, use it for cross-app or cross-site behavioral advertising, or share it with brands for their own marketing purposes.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">How long we keep information</h2>
      <p>
        We keep account and skincare information while your account is active, unless a longer period is required for security, legal, or financial-record purposes. When you delete your account from Settings, we delete your account data from our active systems. Limited data may remain in secure backups until those backups are overwritten.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Your choices</h2>
      <p>
        You can access and update your saved information in the app. From Settings, you can export your data and request permanent account deletion. You can decline camera or photo-library permission; scanning features will simply be unavailable. You can manage or cancel a subscription through the store or payment method used to purchase it.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Security</h2>
      <p>
        We use access controls designed to limit each account to its own data and rely on industry-standard providers for authentication, payment processing, and hosting. No method of electronic storage or transmission is completely secure, so we cannot guarantee absolute security.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Children</h2>
      <p>
        Skintel is not directed to children under 13. If you believe a child has provided personal information without appropriate consent, contact us and we will take appropriate action.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Changes to this policy</h2>
      <p>
        We may update this policy when our practices or the service change. We will post the current version here and update the date below.
      </p>

      <h2 className="font-display text-2xl mt-8 mb-2">Contact us</h2>
      <p>
        For privacy questions, requests, or concerns, email{' '}
        <a href="mailto:hello@skinstel.com" className="text-primary underline-offset-4 hover:underline">
          hello@skinstel.com
        </a>.
      </p>

      <p className="text-sm text-muted pt-6">Last updated: {updatedDate}</p>
    </PublicPage>
  );
}
