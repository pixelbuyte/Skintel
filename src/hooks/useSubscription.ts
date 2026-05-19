import { useCallback, useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import type { Subscription, Tier } from '@/lib/types';
import { useAuth } from './useAuth';

const FREE_PRODUCT_LIMIT = 5;

export function useSubscription() {
  const { user } = useAuth();
  const [sub, setSub] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchSub = useCallback(async () => {
    if (!user) {
      setSub(null);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data } = await supabase.from('subscriptions').select('*').eq('user_id', user.id).maybeSingle();
    setSub((data as Subscription) ?? null);
    setLoading(false);
  }, [user]);

  useEffect(() => {
    fetchSub();
  }, [fetchSub]);

  const tier: Tier = sub?.tier ?? 'free';
  const isPaid = tier === 'pro' || tier === 'founding';

  return {
    subscription: sub,
    tier,
    loading,
    isPaid,
    productLimit: isPaid ? Infinity : FREE_PRODUCT_LIMIT,
    canUseScanner: isPaid,
    refresh: fetchSub,
  };
}
