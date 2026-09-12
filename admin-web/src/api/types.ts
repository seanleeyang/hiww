export type OrderStatus =
  | 'pending_payment'
  | 'confirmed'
  | 'purchased'
  | 'in_transit'
  | 'delivered'
  | 'cancelled';

export interface UserSummary {
  id: string;
  full_name: string;
  avatar_url?: string | null;
  rating_avg?: number | null;
  rating_count?: number;
  delivered_count?: number;
}

export interface AdminUser {
  id: string;
  email: string;
  full_name: string;
  user_type: 'shopper' | 'traveler' | 'both';
  role: 'user' | 'admin';
  kyc_status: 'pending' | 'approved' | 'rejected';
  risk_status: 'clear' | 'flagged' | 'restricted';
  created_at: string;
}

export interface Order {
  id: string;
  shopper_id: string;
  traveler_id: string;
  trip_id?: string | null;
  request_id?: string | null;
  offer_id?: string | null;
  item_description: string;
  quantity: number;
  unit_price: string;
  total_price: string;
  fees: string;
  status: OrderStatus;
  payment_claimed_at?: string | null;
  payment_deadline_at?: string | null;
  cancelled_at?: string | null;
  confirmed_at?: string | null;
  purchase_proof_url?: string | null;
  purchased_at?: string | null;
  item_photo_url?: string | null;
  receipt_risk?: 'low' | 'medium' | 'high' | null;
  shipped_at?: string | null;
  shipping_proof_url?: string | null;
  delivered_at?: string | null;
  delivery_proof_url?: string | null;
  traveller_reward?: string | null;
  shopper_total?: string | null;
  traveller_payout?: string | null;
  currency?: string | null;
  counterparty?: UserSummary | null;
  request_image_url?: string | null;
  request_category?: string | null;
  created_at: string;
  updated_at: string;
}

export interface Dispute {
  id: string;
  order_id: string;
  initiator_id: string;
  reason: string;
  status: 'open' | 'in_review' | 'resolved' | 'closed';
  resolution?: string | null;
  created_at: string;
}

export interface Trip {
  id: string;
  traveler_id: string;
  departure_country: string;
  arrival_country: string;
  departure_city?: string | null;
  arrival_city?: string | null;
  title?: string | null;
  status: 'published' | 'in_progress' | 'completed' | 'cancelled';
  departure_date: string;
  return_date: string;
  created_at: string;
  traveler_email: string;
  traveler_name: string;
}

export interface Want {
  id: string;
  shopper_id: string;
  item_description: string;
  title?: string | null;
  source_country: string;
  source_city?: string | null;
  category: string;
  budget: string;
  status: 'open' | 'accepted' | 'completed' | 'cancelled';
  created_at: string;
  shopper_email: string;
  shopper_name: string;
}

export interface AdminOffer {
  id: string;
  request_id: string;
  trip_id?: string | null;
  quoted_price: string;
  status: 'pending' | 'accepted' | 'rejected' | 'expired';
  round: number;
  last_actor?: 'traveler' | 'shopper' | null;
  respond_by?: string | null;
  created_at: string;
  item_description: string;
  traveler_id: string;
  traveler_name: string;
  shopper_id: string;
  shopper_name: string;
}

export interface AdminReview {
  id: string;
  order_id: string;
  rating: number;
  comment?: string | null;
  hidden_at?: string | null;
  created_at: string;
  reviewer_id: string;
  reviewer_name: string;
  reviewee_id: string;
  reviewee_name: string;
  item_description: string;
}

export interface AuditEntry {
  id: string;
  actor_id?: string | null;
  actor_role?: string | null;
  action: string;
  target_type: string;
  target_id: string;
  summary: string;
  metadata: Record<string, unknown>;
  created_at: string;
}

// The unified moderation-queue entries from GET /api/admin/reviews — kept as
// a discriminated union on `type` since each kind carries different fields.
export type QueueItem =
  | ({ type: 'dispute' } & Dispute)
  | {
      type: 'kyc';
      id: string;
      status: string;
      user_id: string;
      email: string;
      full_name: string;
      document_type: 'passport' | 'id_card' | null;
      document_id: string | null;
      /** Name/address as filled in on the form — may differ from the account's own. */
      first_name: string | null;
      last_name: string | null;
      address: string | null;
      document_photo_url: string | null;
      /** Photo of the user holding the document, for the AI face-match check. */
      selfie_photo_url: string | null;
      /** Advisory AI cross-check — never sets `status` itself. */
      ai_risk: 'low' | 'medium' | 'high' | null;
      ai_analysis: {
        summary?: string;
        flags?: string[];
        extracted?: { firstName?: string | null; lastName?: string | null; documentId?: string | null; address?: string | null };
        nameMatch?: 'match' | 'mismatch' | 'unclear';
        documentIdMatch?: 'match' | 'mismatch' | 'unclear';
        addressMatch?: 'match' | 'mismatch' | 'unclear';
        faceMatch?: 'match' | 'mismatch' | 'unclear';
        documentAuthenticity?: 'plausible' | 'suspicious';
      } | null;
      submitted_at: string | null;
      created_at: string;
    }
  | {
      type: 'receipt';
      id: string;
      order_id: string;
      status: OrderStatus;
      item_description: string;
      total_price: string;
      receipt_url?: string | null;
      item_photo_url?: string | null;
      risk: 'medium' | 'high';
      flags: string[];
      summary?: string | null;
      extracted?: Record<string, unknown> | null;
      item_photo_assessment?: string | null;
      created_at: string;
    }
  | {
      type: 'message';
      id: string;
      order_id: string;
      sender_id: string;
      sender_name: string;
      body: string;
      risk: 'medium' | 'high';
      flags: string[];
      summary?: string | null;
      hidden: boolean;
      created_at: string;
    };

export interface MoneyOrderRow {
  id: string;
  item_description: string;
  total_price: string;
  fees: string;
  shopper_total?: string | null;
  traveller_payout?: string | null;
  shopper_id?: string;
  traveler_id?: string;
  payment_claimed_at?: string | null;
  delivered_at?: string | null;
  cancelled_at?: string | null;
  created_at?: string;
  /** Traveller's own name + bank details (migration 042) — read-only context
   * for "Record payout"; an admin never types a destination account. */
  traveler_name?: string | null;
  bank_name?: string | null;
  bank_account_number?: string | null;
}

export interface PayoutRow {
  id: string;
  order_id: string;
  amount: string;
  method: string;
  reference: string;
  recorded_by?: string | null;
  created_at: string;
  item_description: string;
  /** Snapshot of the traveller's bank details at payout time (migration 043). */
  bank_name?: string | null;
  bank_account_number?: string | null;
}

export interface RefundRow {
  id: string;
  order_id: string;
  amount: string;
  method: string;
  reference: string;
  recorded_by?: string | null;
  created_at: string;
  item_description: string;
}

export interface Reconciliation {
  awaiting_payment: { count: number; total: string; claimed: number; orders: MoneyOrderRow[] };
  awaiting_payout: { count: number; total: string; orders: MoneyOrderRow[] };
  paid_out: { count: number; total: string; payouts: PayoutRow[] };
  awaiting_refund: { count: number; total: string; orders: MoneyOrderRow[] };
  refunded: { count: number; total: string; refunds: RefundRow[] };
}

export interface OpsOverview {
  users: number;
  shoppers: number;
  travelers: number;
  trips: number;
  requests: number;
  orders: number;
  open_requests: number;
  published_trips: number;
  pending_orders: number;
}
