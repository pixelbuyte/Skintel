export const STRIPE_PRICES = {
  pro_monthly: import.meta.env.VITE_STRIPE_PRICE_PRO ?? '',
  pro_yearly: import.meta.env.VITE_STRIPE_PRICE_PRO_YEARLY ?? '',
  founding: import.meta.env.VITE_STRIPE_PRICE_FOUNDING ?? '',
};

export const TIER_BY_PRICE: Record<string, 'pro' | 'founding'> = {
  [STRIPE_PRICES.pro_monthly]: 'pro',
  [STRIPE_PRICES.pro_yearly]: 'pro',
  [STRIPE_PRICES.founding]: 'founding',
};
