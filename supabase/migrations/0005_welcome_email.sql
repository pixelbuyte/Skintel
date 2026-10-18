-- Welcome email: when a user's email becomes confirmed (email sign-up confirmed, or Sign in
-- with Apple, which arrives confirmed), POST the user id to /api/account?action=welcome.
-- The API looks the address up itself and sends at most one welcome per user.
--
-- Before running, store the shared secret (same value as Vercel env EMAIL_WEBHOOK_SECRET):
--   select vault.create_secret('<long random string>', 'email_webhook_secret');
-- Then paste this file into the Supabase SQL editor and run. Additive only.
-- The HTTP call is async (pg_net), so a slow or failed send never blocks sign-up.

create extension if not exists pg_net with schema extensions;

create or replace function public.notify_welcome_email()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  secret text;
begin
  if new.email_confirmed_at is null then return new; end if;
  if tg_op = 'UPDATE' and old.email_confirmed_at is not null then return new; end if;

  select decrypted_secret into secret from vault.decrypted_secrets where name = 'email_webhook_secret' limit 1;
  if secret is null then return new; end if;

  perform net.http_post(
    url := 'https://skinstel.com/api/account?action=welcome',
    body := jsonb_build_object('user_id', new.id),
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-webhook-secret', secret),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  -- Never let email break sign-up.
  return new;
end;
$$;

drop trigger if exists on_auth_user_confirmed_welcome on auth.users;
create trigger on_auth_user_confirmed_welcome
  after insert or update of email_confirmed_at on auth.users
  for each row execute function public.notify_welcome_email();
