export const STRIPE_PRICES = {
  pro: import.meta.env.VITE_STRIPE_PRICE_PRO ?? '',
  founding: import.meta.env.VITE_STRIPE_PRICE_FOUNDING ?? '',
};

export const TIER_BY_PRICE: Record<string, 'pro' | 'founding'> = {
  [STRIPE_PRICES.pro]: 'pro',
  [STRIPE_PRICES.founding]: 'founding',
};
