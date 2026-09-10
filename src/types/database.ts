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
  /** Contact + delivery details (migration 018), all private (self-view only). */
  phone?: string | null;
  address_street?: string | null;
  address_city?: string | null;
  address_postal_code?: string | null;
  address_country?: string | null;
  /**
   * Set once the matching OTP is confirmed (migration 020). Null on a fresh
   * registration; existing rows were grandfathered to `created_at` when this
   * shipped. See `src/services/otp/`.
   */
  email_verified_at?: Date | null;
  phone_verified_at?: Date | null;
  /**
   * Social sign-in (migration 026). Null for a plain email/password account.
   * `provider_user_id` is that provider's stable subject id (e.g. Google's
   * `sub` claim) — never the email, since an email can change or be reused.
   */
  auth_provider?: 'google' | 'apple' | 'facebook' | 'line' | null;
  provider_user_id?: string | null;
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
  /** Cleared from the owner's own My Trips list (migration 024) — history untouched. */
  archived_at?: Date | null;
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
  /** How many of the item the shopper wants (migration 013). */
  quantity: Generated<number>;
  status: 'open' | 'accepted' | 'completed' | 'cancelled';
  /** Presentation fields (migration 007). */
  title?: string | null;
  source_city?: string | null;
  need_by?: Date | null;
  image_url?: string | null;
  /**
   * Set when this want was created via "Request from this trip" (migration
   * 023) instead of posted publicly — excluded from `GET /api/requests`
   * (the public browse feed); see `src/modules/requests/routes.ts`.
   */
  target_trip_id?: string | null;
  /** Cleared from the owner's own My Wants list (migration 024) — history untouched. */
  archived_at?: Date | null;
  /**
   * Delivery destination (migration 027) — where the item should end up,
   * distinct from source_country/source_city (where to buy it). Required at
   * create time via Zod, nullable here only because existing rows predate it.
   */
  destination_country: string;
  destination_city?: string | null;
  product_url?: string | null;
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
  /**
   * Negotiation state (migration 022). `round` counts counters made so far,
   * capped at 2 — see `src/modules/offers/routes.ts`. `last_actor` is who
   * proposed the current `quoted_price` (the other side responds next).
   * `respond_by` is enforced lazily like the payment timeout; see
   * `src/services/offer-expiry.ts`. `price_history` is every price
   * proposed, `[{by, price, at}]`, for the negotiation thread UI.
   */
  round: Generated<number>;
  last_actor?: 'traveler' | 'shopper' | null;
  respond_by?: Date | null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  price_history: Generated<Record<string, any>[]>;
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
  status:
    | 'pending_payment'
    | 'confirmed'
    | 'purchased'
    | 'in_transit'
    | 'delivered'
    | 'cancelled';
  /** Set when the shopper says they have sent payment (manual-money pilot signal). */
  payment_claimed_at?: Date | null;
  /**
   * Auto-cancel deadline (migration 021) — set at order creation to
   * now + PAYMENT_TIMEOUT_MINUTES. Enforced lazily; see
   * `src/services/order-expiry.ts`. `cancelled_at` is set whenever an order
   * actually cancels, for this reason or any future one.
   */
  payment_deadline_at?: Date | null;
  cancelled_at?: Date | null;
  /** Per-stage timestamps for the order tracker (migration 007). */
  confirmed_at?: Date | null;
  /** Traveler's shop-receipt photo + when they marked the item bought (migration 013). */
  purchase_proof_url?: string | null;
  purchased_at?: Date | null;
  /** Traveler's photo of the item itself, alongside the receipt (migration 030). */
  item_photo_url?: string | null;
  /** Last time the traveler was nudged to upload it (migration 031); see `src/services/upload-reminder.ts`. */
  last_upload_reminder_at?: Date | null;
  /** AI receipt check output (migration 014); see `src/services/ai/`. */
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  receipt_analysis?: Record<string, any> | null;
  receipt_risk?: 'low' | 'medium' | 'high' | null;
  receipt_reviewed_at?: Date | null;
  shipped_at?: Date | null;
  /** Traveler's optional photo/screenshot of the item being shipped (migration 033). */
  shipping_proof_url?: string | null;
  delivered_at?: Date | null;
  /**
   * MVP pricing model split (migration 028) — see `src/services/pricing.ts`.
   * `total_price`/`fees` above keep their existing meaning ("goods price" /
   * "platform's cut") unchanged; these are the additional legs. Nullable
   * and never backfilled: orders created before this migration were priced
   * under the old flat-fee model and keep exactly those numbers forever.
   */
  traveller_reward?: string | null;
  shopper_total?: string | null;
  traveller_payout?: string | null;
  currency?: string | null;
  /**
   * Order chat closes once `status` reaches `delivered` (migration 029) —
   * see `messages/routes.ts`. Either side can then "delete" the closed
   * chat from their own view; this only sets their own timestamp, never
   * touches the message rows or the other side's copy.
   */
  chat_deleted_by_shopper_at?: Date | null;
  chat_deleted_by_traveler_at?: Date | null;
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
  /** Structured data used to re-render subject/body in the reader's locale.
   * Null on rows written before this existed — those keep their stored
   * (English) subject/body. */
  params?: Record<string, string | number> | null;
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
  image_url?: string | null;
  created_at: Generated<Date>;
  read_at?: Date | null;
  flag_risk?: 'medium' | 'high' | null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  flag_reasons?: any[] | null;
  flag_summary?: string | null;
  flag_reviewed_at?: Date | null;
  hidden_at?: Date | null;
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

/** One-time codes for email/phone verification (migration 020). */
export interface OtpCodesTable {
  id: string;
  user_id: string;
  channel: 'email' | 'phone';
  code: string;
  expires_at: Date;
  consumed_at?: Date | null;
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
  otp_codes: OtpCodesTable;
  device_tokens: DeviceTokensTable;
}

/** One registered device for push notifications (migration 032). */
export interface DeviceTokensTable {
  id: string;
  user_id: string;
  token: string;
  platform: string;
  created_at: Generated<Date>;
  updated_at: Generated<Date>;
}
