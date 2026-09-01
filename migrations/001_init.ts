import { Kysely } from 'kysely';

export async function up(db: Kysely<any>): Promise<void> {
  // Create users table
  await db.schema
    .createTable('users')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('email', 'varchar', (col) => col.notNull().unique())
    .addColumn('full_name', 'varchar', (col) => col.notNull())
    .addColumn('user_type', 'varchar', (col) => col.notNull())
    .addColumn('kyc_status', 'varchar', (col) => col.notNull().defaultTo('pending'))
    .addColumn('risk_status', 'varchar', (col) => col.notNull().defaultTo('clear'))
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .addColumn('updated_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create trips table
  await db.schema
    .createTable('trips')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('traveler_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('departure_country', 'varchar', (col) => col.notNull())
    .addColumn('arrival_country', 'varchar', (col) => col.notNull())
    .addColumn('departure_date', 'timestamp', (col) => col.notNull())
    .addColumn('return_date', 'timestamp', (col) => col.notNull())
    .addColumn('status', 'varchar', (col) => col.notNull().defaultTo('published'))
    .addColumn('max_weight_kg', 'numeric', (col) => col.notNull())
    .addColumn('max_items', 'integer', (col) => col.notNull())
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .addColumn('updated_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create requests table (shopper-initiated flow)
  await db.schema
    .createTable('requests')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('shopper_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('item_description', 'text', (col) => col.notNull())
    .addColumn('source_country', 'varchar', (col) => col.notNull())
    .addColumn('category', 'varchar', (col) => col.notNull())
    .addColumn('estimated_weight_kg', 'numeric', (col) => col.notNull())
    .addColumn('budget', 'numeric', (col) => col.notNull())
    .addColumn('status', 'varchar', (col) => col.notNull().defaultTo('open'))
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .addColumn('updated_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create offers table
  await db.schema
    .createTable('offers')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('traveler_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('request_id', 'uuid', (col) =>
      col.notNull().references('requests.id').onDelete('cascade')
    )
    .addColumn('quoted_price', 'numeric', (col) => col.notNull())
    .addColumn('delivery_date', 'timestamp', (col) => col.notNull())
    .addColumn('status', 'varchar', (col) => col.notNull().defaultTo('pending'))
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .addColumn('updated_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create orders table
  await db.schema
    .createTable('orders')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('shopper_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('traveler_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('trip_id', 'uuid', (col) => col.references('trips.id').onDelete('no action'))
    .addColumn('request_id', 'uuid', (col) => col.references('requests.id').onDelete('no action'))
    .addColumn('offer_id', 'uuid', (col) => col.references('offers.id').onDelete('no action'))
    .addColumn('item_description', 'text', (col) => col.notNull())
    .addColumn('quantity', 'integer', (col) => col.notNull())
    .addColumn('unit_price', 'numeric', (col) => col.notNull())
    .addColumn('total_price', 'numeric', (col) => col.notNull())
    .addColumn('fees', 'numeric', (col) => col.notNull().defaultTo('0'))
    .addColumn('status', 'varchar', (col) => col.notNull().defaultTo('pending_payment'))
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .addColumn('updated_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create ledger_entries table
  await db.schema
    .createTable('ledger_entries')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('user_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('order_id', 'uuid', (col) =>
      col.notNull().references('orders.id').onDelete('cascade')
    )
    .addColumn('entry_type', 'varchar', (col) => col.notNull())
    .addColumn('amount', 'numeric', (col) => col.notNull())
    .addColumn('balance_after', 'numeric', (col) => col.notNull())
    .addColumn('description', 'text', (col) => col.notNull())
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create fees table
  await db.schema
    .createTable('fees')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('order_id', 'uuid', (col) =>
      col.notNull().references('orders.id').onDelete('cascade')
    )
    .addColumn('fee_type', 'varchar', (col) => col.notNull())
    .addColumn('amount', 'numeric', (col) => col.notNull())
    .addColumn('percentage', 'numeric')
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create evidence table
  await db.schema
    .createTable('evidence')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('order_id', 'uuid', (col) =>
      col.notNull().references('orders.id').onDelete('cascade')
    )
    .addColumn('evidence_type', 'varchar', (col) => col.notNull())
    .addColumn('url', 'varchar', (col) => col.notNull())
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create disputes table
  await db.schema
    .createTable('disputes')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('order_id', 'uuid', (col) =>
      col.notNull().references('orders.id').onDelete('cascade')
    )
    .addColumn('initiator_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('reason', 'text', (col) => col.notNull())
    .addColumn('status', 'varchar', (col) => col.notNull().defaultTo('open'))
    .addColumn('resolution', 'text')
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .addColumn('updated_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();

  // Create notifications table
  await db.schema
    .createTable('notifications')
    .addColumn('id', 'uuid', (col) => col.primaryKey())
    .addColumn('user_id', 'uuid', (col) =>
      col.notNull().references('users.id').onDelete('cascade')
    )
    .addColumn('type', 'varchar', (col) => col.notNull())
    .addColumn('subject', 'varchar', (col) => col.notNull())
    .addColumn('body', 'text', (col) => col.notNull())
    .addColumn('sent_at', 'timestamp')
    .addColumn('read_at', 'timestamp')
    .addColumn('created_at', 'timestamp', (col) => col.notNull().defaultTo('now()'))
    .execute();
}

export async function down(db: Kysely<any>): Promise<void> {
  await db.schema.dropTable('notifications').ifExists().execute();
  await db.schema.dropTable('disputes').ifExists().execute();
  await db.schema.dropTable('evidence').ifExists().execute();
  await db.schema.dropTable('fees').ifExists().execute();
  await db.schema.dropTable('ledger_entries').ifExists().execute();
  await db.schema.dropTable('orders').ifExists().execute();
  await db.schema.dropTable('offers').ifExists().execute();
  await db.schema.dropTable('requests').ifExists().execute();
  await db.schema.dropTable('trips').ifExists().execute();
  await db.schema.dropTable('users').ifExists().execute();
}
