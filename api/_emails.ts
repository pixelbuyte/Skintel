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
<tr><td align="center" style="padding:20px 4px 0;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;color:#8A7A6C;">
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
  const tile = (icon: string, title: string, text: string) =>
    `<td valign="top" width="50%" style="padding:0 8px 18px;">
<img src="${ASSETS}/${icon}.png" width="40" height="40" alt="" style="display:block;border:0;margin-bottom:10px;">
<strong style="font-size:15px;">${title}</strong><br><span style="font-size:14px;line-height:1.45;color:#5E554C;">${text}</span></td>`;
  return {
    subject: 'Your skin deserves better than guesswork',
    html: layout({
      preheader: 'Start with one scan. Skintel takes it from there.',
      body: `<h1 style="margin:0 0 10px;font-family:Georgia,'Times New Roman',serif;font-weight:400;font-size:28px;line-height:1.15;">Your skin deserves better than guesswork.</h1>
<p style="margin:0 0 24px;color:#5E554C;">You've tried the products. Now find out which one is actually the problem.</p>
<table role="presentation" cellpadding="0" cellspacing="0" width="100%" style="margin:0 -8px;width:calc(100% + 16px);">
<tr>${tile('scan', 'Know what’s in it', 'Scan a bottle and see if it suits your skin.')}${tile('log', 'Teach it your skin', 'A quick daily log shows Skintel what your skin hates.')}</tr>
<tr>${tile('ask', 'Get real answers', 'Ask about any product. Answers built on your skin, not the internet.')}${tile('find', 'Find the culprit', 'See the one ingredient your bad days have in common.')}</tr>
</table>
<table role="presentation" cellpadding="0" cellspacing="0" width="100%"><tr>
<td valign="middle">${button(APP_STORE_URL, 'Scan your first product')}</td>
<td valign="middle" align="right" style="padding-top:16px;"><a href="${APP_STORE_URL}" style="text-decoration:none;"><img src="${ASSETS}/app-icon.png" width="52" height="52" alt="Skintel on the App Store" style="display:block;border:0;border-radius:12px;"></a></td>
</tr></table>`,
    }),
  };
}
