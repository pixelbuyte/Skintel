/**
 * Branded email HTML for Resend sends. Table layout + inline styles so it renders in
 * Gmail, Apple Mail and Outlook. Brand: cream F4EDE0, clay A35848, ink 1A1814.
 * The Supabase auth templates in supabase/templates/ use the same shell.
 */

const esc = (s: string) =>
  s.replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]!);

export function layout({ preheader, body }: { preheader: string; body: string }): string {
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="color-scheme" content="light"></head>
<body style="margin:0;padding:0;background:#F4EDE0;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0">${esc(preheader)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#F4EDE0;"><tr><td align="center" style="padding:40px 16px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;">
<tr><td style="padding:0 4px 20px;font-family:Georgia,'Times New Roman',serif;font-size:26px;color:#1A1814;">Skintel</td></tr>
<tr><td style="background:#FFFEFA;border:1px solid #EAE2D6;border-radius:20px;padding:32px 28px;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;line-height:1.55;color:#1A1814;">
${body}
</td></tr>
<tr><td align="center" style="padding:28px 4px 0;">
<a href="https://apps.apple.com/app/id6812903021" style="text-decoration:none;"><img src="https://skinstel.com/email/app-icon.png" width="56" height="56" alt="Skintel" style="display:block;border:0;border-radius:13px;"></a>
</td></tr>
<tr><td align="center" style="padding:12px 4px 0;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;color:#8A7A6C;">
Skintel · Find the ingredient your bad skin days share.<br>Questions? Reply to this email or write to hello@skinstel.com.
</td></tr>
</table></td></tr></table></body></html>`;
}

export function button(href: string, label: string): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px 0 8px;"><tr><td style="background:#A35848;border-radius:999px;">
<a href="${esc(href)}" style="display:inline-block;padding:14px 28px;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:600;color:#FFFEFA;text-decoration:none;">${esc(label)}</a>
</td></tr></table>`;
}

const ASSETS = 'https://skinstel.com/email';
/** Skintel on the App Store (Apple ID 6812903021). Opens the app if it's installed. */
export const APP_STORE_URL = 'https://apps.apple.com/app/id6812903021';

/** Sent once, after the user's email is confirmed (or on Sign in with Apple). */
export function welcomeEmail(): { subject: string; html: string } {
  const step = (icon: string, title: string, text: string) =>
    `<tr><td valign="top" width="48" style="padding:0 16px 22px 0;"><img src="${ASSETS}/${icon}.png" width="48" height="48" alt="" style="display:block;border:0;"></td>
<td valign="top" style="padding:2px 0 22px;"><strong style="font-size:17px;">${title}</strong><br><span style="color:#5E554C;">${text}</span></td></tr>`;
  return {
    subject: 'Your skin deserves better than guesswork',
    html: layout({
      preheader: 'Scan your shelf, log your skin, and let Skintel find what keeps breaking you out.',
      body: `<h1 style="margin:0 0 12px;font-family:Georgia,'Times New Roman',serif;font-weight:400;font-size:30px;line-height:1.15;">Your skin deserves better than guesswork.</h1>
<p style="margin:0 0 26px;color:#5E554C;">Welcome to Skintel. No more blaming the wrong product. Skintel learns from your own skin and finds what's really behind your bad days.</p>
<table role="presentation" cellpadding="0" cellspacing="0" width="100%">
${step('scan', 'Scan your shelf', 'Point your camera at any barcode or ingredient list. Skintel reads every ingredient for you.')}
${step('log', 'Log your skin every day', 'Ten seconds a day. The more days you log, the sharper your results.')}
${step('ask', 'Ask Skintel anything', '“Is this cleanser okay for me?” Answers come from your own shelf and skin history.')}
${step('find', 'Find your trigger', 'Skintel spots the ingredient your bad days share, so you can finally cut it out.')}
</table>
${button(APP_STORE_URL, 'Open Skintel')}`,
    }),
  };
}
