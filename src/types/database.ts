import type { Generated } from 'kysely';

export interface UsersTable {
  id: string;
  email: string;
  full_name: string;
  user_type: 'shopper' | 'traveler' | 'both';
  kyc_status: Generated<'pending' | 'approved' | 'rejected'>;
  risk_status: Generated<'clear' | 'flagged' | 'restricted'>;
  role: Generated<'user' | 'admin'>;
  password_hash?: string;
  /** Profile + reputation (migration 007). */
  avatar_url?: string | null;
  home_city?: string | null;
  rating_sum: Generated<number>;
  rating_count: Generated<number>;
  delivered_count: Generated<number>;
  created_at: Date;
  updated_at: Date;
}

export interface TripsTable {
  id: string;
  traveler_id: string;
  departure_country: string;
  arrival_country: string;
  departure_date: Date;
  return_date: Date;
  status: 'published' | 'in_progress' | 'completed' | 'cancelled';
  max_weight_kg: number;
  max_items: number;
  /** Presentation fields (migration 007). */
  title?: string | null;
  departure_city?: string | null;
  arrival_city?: string | null;
  note?: string | null;
  cover_image_url?: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface RequestsTable {
  id: string;
  shopper_id: string;
  item_description: string;
  source_country: string;
  category: string;
  estimated_weight_kg: number;
  budget: string; // Decimal as string
  status: 'open' | 'accepted' | 'completed' | 'cancelled';
  /** Presentation fields (migration 007). */
  title?: string | null;
  source_city?: string | null;
  need_by?: Date | null;
  image_url?: string | null;
  created_at: Date;
  updated_at: Date;
}

export interface OffersTable {
  id: string;
  traveler_id: string;
  request_id: string;
  trip_id?: string | null;
  quoted_price: string; // Decimal as string
  delivery_date: Date;
  status: 'pending' | 'accepted' | 'rejected' | 'expired';
  created_at: Date;
  updated_at: Date;
}

export interface OrdersTable {
  id: string;
  shopper_id: string;
  traveler_id: string;
  trip_id?: string;
  request_id?: string;
  offer_id?: string;
  item_description: string;
  quantity: number;
  unit_price: string; // Decimal as string
  total_price: string; // Decimal as string
  fees: string; // Decimal as string
  status: 'pending_payment' | 'confirmed' | 'in_transit' | 'delivered' | 'cancelled';
  /** Set when the shopper says they have sent payment (manual-money pilot signal). */
  payment_claimed_at?: Date | null;
  /** Per-stage timestamps for the order tracker (migration 007). */
  confirmed_at?: Date | null;
  shipped_at?: Date | null;
  delivered_at?: Date | null;
  created_at: Date;
  updated_at: Date;
}

export interface LedgerEntriesTable {
  id: string;
  user_id: string;
  order_id: string;
  entry_type: 'credit' | 'debit' | 'fee' | 'refund';
  amount: string; // Decimal as string
  balance_after: string; // Decimal as string
  description: string;
  created_at: Date;
}

export interface FeesTable {
  id: string;
  order_id: string;
  fee_type: 'platform' | 'payment_processing' | 'currency_conversion';
  amount: string; // Decimal as string
  percentage?: number;
  created_at: Date;
}

export interface EvidenceTable {
  id: string;
  order_id: string;
  evidence_type: 'photo' | 'receipt' | 'document';
  url: string;
  created_at: Date;
}

export interface DisputesTable {
  id: string;
  order_id: string;
  initiator_id: string;
  reason: string;
  status: 'open' | 'in_review' | 'resolved' | 'closed';
  resolution?: string;
  created_at: Date;
  updated_at: Date;
}

/**
 * In-app activity feed. `type` is the event kind (`offer_accepted`,
 * `payment_confirmed`, `shipped`, `delivered`, `payout_sent`, `dispute_opened`,
 * `dispute_resolved`, `payment_claimed`); `link` points at the screen to open
 * (e.g. `/orders/<id>`). See `src/services/notify.ts`.
 */
export interface NotificationsTable {
  id: string;
  user_id: string;
  type: string;
  subject: string;
  body: string;
  order_id?: string | null;
  link?: string | null;
  sent_at?: Date | null;
  read_at?: Date | null;
  created_at: Generated<Date>;
}

export interface ReviewsTable {
  id: string;
  order_id: string;
  reviewer_id: string;
  reviewee_id: string;
  rating: number;
  comment?: string | null;
  created_at: Generated<Date>;
}

export interface MessagesTable {
  id: string;
  order_id: string;
  sender_id: string;
  body: string;
  created_at: Generated<Date>;
  read_at?: Date | null;
}

export interface AuditLogTable {
  id: string;
  actor_id?: string | null;
  actor_role?: string | null;
  action: string;
  target_type: string;
  target_id: string;
  summary: string;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  metadata: Generated<Record<string, any>>;
  created_at: Generated<Date>;
}

export interface PayoutsTable {
  id: string;
  order_id: string;
  recorded_by?: string | null;
  amount: string; // Decimal as string
  method: string;
  reference: string;
  note?: string | null;
  created_at: Generated<Date>;
}

export interface Database {
  users: UsersTable;
  trips: TripsTable;
  requests: RequestsTable;
  offers: OffersTable;
  orders: OrdersTable;
  ledger_entries: LedgerEntriesTable;
  fees: FeesTable;
  evidence: EvidenceTable;
  disputes: DisputesTable;
  notifications: NotificationsTable;
  reviews: ReviewsTable;
  messages: MessagesTable;
  audit_log: AuditLogTable;
  payouts: PayoutsTable;
}
