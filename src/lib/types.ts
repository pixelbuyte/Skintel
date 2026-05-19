export type Outcome = 'good' | 'bad' | 'unsure';
export type Tier = 'free' | 'pro' | 'founding';

export interface Product {
  id: string;
  user_id: string;
  brand: string | null;
  product_name: string;
  category: string | null;
  outcome: Outcome;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface ProductIngredient {
  id: string;
  product_id: string;
  user_id: string;
  position: number;
  inci_raw: string;
  inci_normalized: string;
}

export interface ProductWithIngredients extends Product {
  product_ingredients: ProductIngredient[];
}

export interface Subscription {
  user_id: string;
  tier: Tier;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  status: string | null;
  current_period_end: string | null;
  founding_seat_number: number | null;
  created_at: string;
  updated_at: string;
}

export interface Culprit {
  name: string;
  normalized: string;
  badCount: number;
  goodCount: number;
  badProducts: string[];
  goodProducts: string[];
  risk: 'high' | 'medium';
}
