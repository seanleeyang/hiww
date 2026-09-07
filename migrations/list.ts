// The single ordered list of migrations. `run.ts` and the Jest test bootstrap
// both consume this so there is never a second copy to forget to update.
import * as m001 from './001_init';
import * as m002 from './002_add_auth_fields';
import * as m003 from './003_add_risk_status';
import * as m004 from './004_add_user_role';
import * as m005 from './005_add_order_payment_claim';
import * as m006 from './006_add_offer_trip';
import * as m007 from './007_profiles_and_discovery';
import * as m008 from './008_reviews';
import * as m009 from './009_messages';
import * as m010 from './010_audit_log';
import * as m011 from './011_payouts';
import * as m012 from './012_notifications';
import * as m013 from './013_quantity_and_purchase_proof';
import * as m014 from './014_receipt_analysis';
import * as m015 from './015_message_moderation';
import * as m016 from './016_message_hidden';
import * as m017 from './017_message_image';
import * as m018 from './018_contact_details';
import * as m019 from './019_remove_bio';
import * as m020 from './020_otp_verification';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export const migrations: Array<{ name: string; up: (db: any) => Promise<void> }> = [
  { name: '001_init', up: m001.up },
  { name: '002_add_auth_fields', up: m002.up },
  { name: '003_add_risk_status', up: m003.up },
  { name: '004_add_user_role', up: m004.up },
  { name: '005_add_order_payment_claim', up: m005.up },
  { name: '006_add_offer_trip', up: m006.up },
  { name: '007_profiles_and_discovery', up: m007.up },
  { name: '008_reviews', up: m008.up },
  { name: '009_messages', up: m009.up },
  { name: '010_audit_log', up: m010.up },
  { name: '011_payouts', up: m011.up },
  { name: '012_notifications', up: m012.up },
  { name: '013_quantity_and_purchase_proof', up: m013.up },
  { name: '014_receipt_analysis', up: m014.up },
  { name: '015_message_moderation', up: m015.up },
  { name: '016_message_hidden', up: m016.up },
  { name: '017_message_image', up: m017.up },
  { name: '018_contact_details', up: m018.up },
  { name: '019_remove_bio', up: m019.up },
  { name: '020_otp_verification', up: m020.up },
];
