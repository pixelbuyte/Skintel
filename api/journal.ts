import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

type Condition = 'clear' | 'mild' | 'moderate' | 'breakout';
const CONDITIONS: Condition[] = ['clear', 'mild', 'moderate', 'breakout'];

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

  const sb = getServiceClient();

  if (req.method === 'GET') {
    const { data, error } = await sb
      .from('skin_journal')
      .select('id, entry_date, condition, notes, photo_url, created_at')
      .eq('user_id', user.id)
      .order('entry_date', { ascending: false })
      .limit(90);
    if (error) return json(res, { error: error.message }, 500);
    return json(res, { entries: data ?? [] });
  }

  if (req.method === 'POST') {
    const body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) as {
      entryDate?: string;
      condition?: string;
      notes?: string;
      photoUrl?: string;
    };
    const entryDate = (body?.entryDate ?? '').trim();
    const condition = (body?.condition ?? '').trim() as Condition;
    if (!entryDate || !/^\d{4}-\d{2}-\d{2}$/.test(entryDate)) {
      return json(res, { error: 'Invalid entryDate (YYYY-MM-DD required)' }, 400);
    }
    if (!CONDITIONS.includes(condition)) {
      return json(res, { error: 'Invalid condition' }, 400);
    }
    const notes = body.notes ? String(body.notes).slice(0, 2000) : null;
    const photoUrl = body.photoUrl ? String(body.photoUrl).slice(0, 2000) : null;

    const { data, error } = await sb
      .from('skin_journal')
      .upsert(
        {
          user_id: user.id,
          entry_date: entryDate,
          condition,
          notes,
          photo_url: photoUrl,
        },
        { onConflict: 'user_id,entry_date' },
      )
      .select('id, entry_date, condition, notes, photo_url, created_at')
      .single();
    if (error) return json(res, { error: error.message }, 500);
    return json(res, { entry: data });
  }

  if (req.method === 'DELETE') {
    const id = (req.query?.id ?? '') as string;
    if (!id) return json(res, { error: 'Missing id' }, 400);
    const { error } = await sb
      .from('skin_journal')
      .delete()
      .eq('id', id)
      .eq('user_id', user.id);
    if (error) return json(res, { error: error.message }, 500);
    return json(res, { ok: true });
  }

  return json(res, { error: 'Method not allowed' }, 405);
}
