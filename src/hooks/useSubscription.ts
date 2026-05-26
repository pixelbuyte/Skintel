import { useCallback, useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import type { Subscription, Tier } from '@/lib/types';
import { useAuth } from './useAuth';
import { isPreview } from '@/lib/preview';

const FREE_PRODUCT_LIMIT = 5;

export function useSubscription() {
  const { user } = useAuth();
  const [sub, setSub] = useState<Subscription | null>(null);
  const [loading, setLoading] = useState(!isPreview());

  const fetchSub = useCallback(async () => {
    if (isPreview()) {
      setSub({
        user_id: 'preview-user',
        tier: 'pro',
        stripe_customer_id: null,
        stripe_subscription_id: null,
        status: 'active',
        current_period_end: null,
        founding_seat_number: null,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
      setLoading(false);
      return;
    }
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
