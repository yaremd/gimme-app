import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export interface WishList {
  id: string;
  name: string;
  emoji: string;
  color_hex: string;
  is_shared: boolean;
  share_token: string | null;
  created_at: string;
}

export interface WishItem {
  id: string;
  title: string;
  notes: string | null;
  url: string | null;
  image_url: string | null;
  price_double: number | null;
  currency: string | null;
  priority: "low" | "medium" | "high";
  is_purchased: boolean;
  is_reserved_by_friend: boolean;
  reserved_by_name: string | null;
  reserved_comment: string | null;
  is_pinned: boolean;
  is_archived: boolean;
  created_at: string;
}
