import { getServiceClient } from './_lib';

export const config = { runtime: 'nodejs' };

export default async function handler(_req: Request) {
  const sb = getServiceClient();
  const { data, error } = await sb.rpc('founding_seats_remaining');
  if (error) {
    return new Response(JSON.stringify({ remaining: null, error: error.message }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    });
  }
  return new Response(JSON.stringify({ remaining: data ?? 0 }), {
    headers: {
      'content-type': 'application/json',
      'cache-control': 'public, max-age=10, stale-while-revalidate=30',
    },
  });
}
