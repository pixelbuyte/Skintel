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
<tr><td style="padding:20px 4px 0;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;font-size:12px;line-height:1.5;color:#8A7A6C;">
Skintel · Find the ingredient your bad skin days share.<br>Questions? Reply to this email or write to hello@skinstel.com.
</td></tr>
</table></td></tr></table></body></html>`;
}

export function button(href: string, label: string): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" style="margin:24px 0 8px;"><tr><td style="background:#A35848;border-radius:999px;">
<a href="${esc(href)}" style="display:inline-block;padding:14px 28px;font-family:-apple-system,'Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:600;color:#FFFEFA;text-decoration:none;">${esc(label)}</a>
</td></tr></table>`;
}

/** Sent once, after the user's email is confirmed (or on Sign in with Apple). */
export function welcomeEmail(): { subject: string; html: string } {
  const step = (n: number, title: string, text: string) =>
    `<tr><td valign="top" style="padding:0 14px 16px 0;font-family:Menlo,monospace;font-size:13px;color:#A35848;">0${n}</td>
<td style="padding:0 0 16px;"><strong>${title}</strong><br><span style="color:#5E554C;">${text}</span></td></tr>`;
  return {
    subject: 'Welcome to Skintel',
    html: layout({
      preheader: 'Three small habits and Skintel starts finding your triggers.',
      body: `<h1 style="margin:0 0 12px;font-family:Georgia,'Times New Roman',serif;font-weight:400;font-size:30px;line-height:1.15;">Welcome to Skintel.</h1>
<p style="margin:0 0 22px;color:#5E554C;">Skintel finds the ingredient your bad skin days have in common. Here's how to get there:</p>
<table role="presentation" cellpadding="0" cellspacing="0">
${step(1, 'Scan what you use', 'Point the camera at a barcode or ingredient list to add it to your shelf.')}
${step(2, 'Check in daily', 'Ten seconds: how did your skin feel today?')}
${step(3, 'See your triggers', 'After a few bad days, Triggers shows the ingredient they share.')}
</table>
<p style="margin:8px 0 0;color:#5E554C;">Open the app on your iPhone to start.</p>`,
    }),
  };
}
