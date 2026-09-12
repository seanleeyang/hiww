import type { SupportedLocale } from '@/i18n/locale';

type Params = Record<string, string | number>;
type Entry = { en: string; th: string } | { en: (p: Params) => string; th: (p: Params) => string };

const MESSAGES: Record<string, Entry> = {
  // Shared across modules — identical English text, one translation.
  'common.authRequired': { en: 'Authentication required', th: 'ต้องเข้าสู่ระบบก่อน' },
  'common.userNotFound': { en: 'User not found', th: 'ไม่พบผู้ใช้นี้' },
  'common.orderNotFound': { en: 'Order not found', th: 'ไม่พบคำสั่งซื้อนี้' },
  'common.tripNotFound': { en: 'Trip not found', th: 'ไม่พบทริปนี้' },
  'common.requestNotFound': { en: 'Request not found', th: 'ไม่พบรายการต้องการนี้' },
  'common.offerNotFound': { en: 'Offer not found', th: 'ไม่พบข้อเสนอนี้' },
  'common.disputeNotFound': { en: 'Dispute not found', th: 'ไม่พบข้อพิพาทนี้' },
  'common.fileNotFound': { en: 'File not found', th: 'ไม่พบไฟล์นี้' },
  'common.notYourTrip': { en: 'Not your trip', th: 'ไม่ใช่ทริปของคุณ' },
  'common.notYourWant': { en: 'Not your want', th: 'ไม่ใช่รายการต้องการของคุณ' },
  'common.notPartOfOrder': { en: 'You are not part of this order', th: 'คุณไม่ได้เป็นส่วนหนึ่งของคำสั่งซื้อนี้' },
  'common.waitingOnOtherSide': {
    en: 'You made the current offer — waiting on the other side to respond',
    th: 'คุณเป็นคนเสนอราคาล่าสุด — กำลังรออีกฝ่ายตอบกลับ',
  },
  'common.otpInvalid': { en: 'That code is wrong or has expired', th: 'รหัสไม่ถูกต้องหรือหมดอายุแล้ว' },
  'common.invalidKycReviewPayload': { en: 'Invalid KYC review payload', th: 'ข้อมูลตรวจสอบ KYC ไม่ถูกต้อง' },
  'common.invalidDisputeResolutionPayload': {
    en: 'Invalid dispute resolution payload',
    th: 'ข้อมูลการตัดสินข้อพิพาทไม่ถูกต้อง',
  },
  'common.orderIdRequired': { en: 'order_id is required', th: 'ต้องระบุ order_id' },
  'common.internalServerError': { en: 'Internal server error', th: 'เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์' },
  'common.requestFailed': { en: 'Request failed', th: 'คำขอไม่สำเร็จ' },

  // middleware/auth-guard.ts
  'authGuard.adminRequired': { en: 'Administrator access required', th: 'ต้องเป็นผู้ดูแลระบบเท่านั้น' },
  'authGuard.verificationRequired': {
    en: 'Verify your email and phone to continue',
    th: 'กรุณายืนยันอีเมลและเบอร์โทรศัพท์ก่อนดำเนินการต่อ',
  },
  'authGuard.accountSuspended': {
    en: (p) => `Your account is suspended until ${p.until}.`,
    th: (p) => `บัญชีของคุณถูกระงับจนถึง ${p.until}`,
  },
  'authGuard.accountBanned': {
    en: 'Your account has been permanently banned.',
    th: 'บัญชีของคุณถูกปิดถาวร',
  },

  // utils/profile-guard.ts
  'profileGuard.incompletePhoneAndAddress': {
    en: 'Add your phone number and delivery address before your first order',
    th: 'กรุณาเพิ่มเบอร์โทรศัพท์และที่อยู่จัดส่งก่อนทำคำสั่งซื้อแรกของคุณ',
  },
  'profileGuard.incompletePhone': {
    en: 'Add your phone number before your first order',
    th: 'กรุณาเพิ่มเบอร์โทรศัพท์ก่อนทำคำสั่งซื้อแรกของคุณ',
  },
  'profileGuard.incompleteAddress': {
    en: 'Add your delivery address before your first order',
    th: 'กรุณาเพิ่มที่อยู่จัดส่งก่อนทำคำสั่งซื้อแรกของคุณ',
  },

  // modules/admin/actions.ts
  'adminActions.invalidDisputeResolution': {
    en: 'Invalid dispute resolution payload',
    th: 'ข้อมูลการตัดสินข้อพิพาทไม่ถูกต้อง',
  },
  'adminActions.invalidRiskFlag': { en: 'Invalid risk flag payload', th: 'ข้อมูลการตั้งค่าความเสี่ยงไม่ถูกต้อง' },
  'adminActions.invalidViolation': { en: 'Enter a reason for this violation', th: 'กรุณาระบุเหตุผลสำหรับการละเมิดนี้' },
  'adminActions.invalidCancelPayload': { en: 'Invalid cancel payload', th: 'ข้อมูลการยกเลิกไม่ถูกต้อง' },
  'adminActions.orderAlreadyCancelled': { en: 'This order is already cancelled', th: 'คำสั่งซื้อนี้ถูกยกเลิกไปแล้ว' },
  'adminActions.orderAlreadyPaidOut': {
    en: 'This order has already been paid out and can no longer be cancelled',
    th: 'คำสั่งซื้อนี้จ่ายเงินไปแล้วและไม่สามารถยกเลิกได้อีก',
  },
  'adminActions.invalidRefundPayload': { en: 'Invalid refund payload', th: 'ข้อมูลการคืนเงินไม่ถูกต้อง' },

  // modules/admin/routes.ts
  'admin.dbErrorReviewQueue': { en: 'Failed to load admin review queue', th: 'โหลดคิวตรวจสอบของผู้ดูแลระบบไม่สำเร็จ' },
  'admin.messageNotFound': { en: 'Message not found', th: 'ไม่พบข้อความนี้' },
  'admin.reviewNotFound': { en: 'Review not found', th: 'ไม่พบรีวิวนี้' },

  // modules/auth/routes.ts
  'auth.invalidRegistration': { en: 'Invalid registration data', th: 'ข้อมูลการสมัครไม่ถูกต้อง' },
  'auth.userExists': { en: 'User already exists', th: 'มีผู้ใช้นี้อยู่แล้ว' },
  'auth.invalidLogin': { en: 'Invalid login data', th: 'ข้อมูลเข้าสู่ระบบไม่ถูกต้อง' },
  'auth.invalidCredentials': { en: 'Invalid email or password', th: 'อีเมลหรือรหัสผ่านไม่ถูกต้อง' },
  'auth.invalidEmail': { en: 'Invalid email', th: 'อีเมลไม่ถูกต้อง' },
  'auth.invalidResetDetails': { en: 'Invalid reset details', th: 'ข้อมูลรีเซ็ตรหัสผ่านไม่ถูกต้อง' },
  'auth.invalidChangePassword': {
    en: 'Password must be 8-128 characters and contain both letters and numbers',
    th: 'รหัสผ่านต้องมี 8-128 ตัวอักษร และประกอบด้วยตัวอักษรและตัวเลข',
  },
  'auth.currentPasswordIncorrect': { en: 'Current password is incorrect', th: 'รหัสผ่านปัจจุบันไม่ถูกต้อง' },
  'auth.invalidProfileUpdate': { en: 'Invalid profile update', th: 'ข้อมูลอัปเดตโปรไฟล์ไม่ถูกต้อง' },
  'auth.invalidVerificationCode': { en: 'Invalid verification code', th: 'รหัสยืนยันไม่ถูกต้อง' },
  'auth.invalidChannel': { en: 'Invalid channel', th: 'ช่องทางไม่ถูกต้อง' },
  'auth.noPhoneOnFile': { en: 'No phone number on file yet', th: 'ยังไม่มีเบอร์โทรศัพท์ในระบบ' },
  'auth.invalidSocialPayload': { en: 'Invalid sign-in request', th: 'คำขอเข้าสู่ระบบไม่ถูกต้อง' },
  'auth.socialProviderNotConfigured': {
    en: 'That sign-in method isn’t set up yet',
    th: 'ยังไม่ได้ตั้งค่าการเข้าสู่ระบบวิธีนี้',
  },
  'auth.invalidSocialToken': {
    en: 'Could not verify that sign-in. Please try again.',
    th: 'ไม่สามารถยืนยันการเข้าสู่ระบบได้ กรุณาลองใหม่อีกครั้ง',
  },
  'auth.socialEmailRequired': {
    en: 'Hiww needs an email address to create your account, and this sign-in didn’t share one. Please try another sign-in method.',
    th: 'Hiww ต้องใช้อีเมลเพื่อสร้างบัญชีของคุณ แต่การเข้าสู่ระบบนี้ไม่ได้แชร์อีเมลมาให้ กรุณาลองใช้วิธีอื่น',
  },

  // modules/compliance/routes.ts
  'compliance.invalidKycSubmission': { en: 'Invalid KYC submission', th: 'ข้อมูลยืนยันตัวตนไม่ถูกต้อง' },

  // modules/disputes/routes.ts
  'disputes.invalidPayload': { en: 'Invalid dispute payload', th: 'ข้อมูลข้อพิพาทไม่ถูกต้อง' },
  'disputes.onlyParticipantsCanOpen': {
    en: 'Only order participants can open disputes',
    th: 'เฉพาะผู้ที่เกี่ยวข้องกับคำสั่งซื้อเท่านั้นที่เปิดข้อพิพาทได้',
  },
  'disputes.notOpen': { en: 'Dispute is not open', th: 'ข้อพิพาทนี้ไม่ได้เปิดอยู่' },

  // modules/evidence/routes.ts
  'evidence.invalidPayload': { en: 'Invalid evidence payload', th: 'ข้อมูลหลักฐานไม่ถูกต้อง' },
  'evidence.onlyParticipantsUpload': {
    en: 'Only order participants can upload evidence',
    th: 'เฉพาะผู้ที่เกี่ยวข้องกับคำสั่งซื้อเท่านั้นที่อัปโหลดหลักฐานได้',
  },
  'evidence.onlyParticipantsView': {
    en: 'Only order participants can view evidence',
    th: 'เฉพาะผู้ที่เกี่ยวข้องกับคำสั่งซื้อเท่านั้นที่ดูหลักฐานได้',
  },

  // modules/external/routes.ts
  'external.invalidPayload': {
    en: 'Invalid identity verification payload',
    th: 'ข้อมูลยืนยันตัวตนไม่ถูกต้อง',
  },

  // modules/messages/routes.ts
  'messages.invalidBody': { en: 'Provide a message or a photo', th: 'กรุณาใส่ข้อความหรือรูปภาพ' },
  'messages.chatClosed': {
    en: 'This chat is closed — the order is complete',
    th: 'แชทนี้ปิดแล้ว — คำสั่งซื้อเสร็จสมบูรณ์แล้ว',
  },
  'messages.chatNotYetClosed': {
    en: 'You can delete this chat once the order is complete',
    th: 'คุณสามารถลบแชทนี้ได้เมื่อคำสั่งซื้อเสร็จสมบูรณ์แล้ว',
  },
  'messages.leakageWarning': {
    en: "We removed contact details or off-platform payment mentions from your message to keep everyone safe — the rest still sent. Messages are reviewed for anything else that looks unsafe.",
    th: 'เราได้ลบข้อมูลติดต่อหรือข้อความเกี่ยวกับการชำระเงินนอกแพลตฟอร์มออกจากข้อความของคุณเพื่อความปลอดภัย — ส่วนที่เหลือถูกส่งแล้ว ข้อความจะถูกตรวจสอบหากมีสิ่งอื่นที่ดูไม่ปลอดภัย',
  },
  'messages.qrWarning': {
    en: "We removed a QR code from your photo — sharing payment or contact QR codes isn't allowed here. Messages are reviewed for anything else that looks unsafe.",
    th: 'เราได้ลบ QR โค้ดออกจากรูปภาพของคุณ — ไม่อนุญาตให้แชร์ QR โค้ดสำหรับชำระเงินหรือติดต่อที่นี่ ข้อความจะถูกตรวจสอบหากมีสิ่งอื่นที่ดูไม่ปลอดภัย',
  },
  'messages.profanityWarning': {
    en: 'We removed offensive language from your message to keep the conversation respectful — the rest still sent.',
    th: 'เราได้ลบคำหยาบคายออกจากข้อความของคุณเพื่อให้การสนทนาสุภาพ — ส่วนที่เหลือถูกส่งแล้ว',
  },
  'messages.hiddenToSender': {
    en: "Your message was removed — it didn't meet Hiww's chat guidelines and is under review.",
    th: 'ข้อความของคุณถูกลบออก — ไม่เป็นไปตามแนวทางการแชทของ Hiww และอยู่ระหว่างการตรวจสอบ',
  },
  'messages.hiddenToOthers': {
    en: "A message was removed — it didn't meet Hiww's chat guidelines.",
    th: 'ข้อความหนึ่งถูกลบออก — ไม่เป็นไปตามแนวทางการแชทของ Hiww',
  },

  // modules/money/routes.ts
  'money.notImplemented': {
    en: 'Automated payment capture is not implemented yet',
    th: 'ยังไม่รองรับการรับชำระเงินอัตโนมัติ',
  },
  'money.invalidPayoutPayload': { en: 'Invalid payout payload', th: 'ข้อมูลการจ่ายเงินไม่ถูกต้อง' },
  'money.onlyDeliveredCanPayout': {
    en: 'Only a delivered order can be paid out',
    th: 'จ่ายเงินได้เฉพาะคำสั่งซื้อที่จัดส่งสำเร็จแล้วเท่านั้น',
  },
  'money.alreadyPaidOut': { en: 'This order has already been paid out', th: 'คำสั่งซื้อนี้จ่ายเงินไปแล้ว' },
  'money.travelerBankAccountMissing': {
    en: 'This traveler has not added their bank account yet — ask them to add it in the app before recording this payout',
    th: 'นักเดินทางคนนี้ยังไม่ได้เพิ่มบัญชีธนาคาร กรุณาแจ้งให้เพิ่มในแอปก่อนบันทึกการจ่ายเงินนี้',
  },
  'money.onlyCancelledCanRefund': {
    en: 'Only a cancelled order with confirmed payment can be refunded',
    th: 'คืนเงินได้เฉพาะคำสั่งซื้อที่ถูกยกเลิกและยืนยันการชำระเงินแล้วเท่านั้น',
  },
  'money.alreadyRefunded': { en: 'This order has already been refunded', th: 'คำสั่งซื้อนี้คืนเงินไปแล้ว' },

  // services/pricing.ts
  'pricing.invalidItemPrice': {
    en: 'Item price must be a valid, non-negative amount',
    th: 'ราคาสินค้าต้องเป็นจำนวนที่ถูกต้องและไม่ติดลบ',
  },

  // modules/notifications/routes.ts
  'notifications.invalidReadPayload': { en: 'Invalid read payload', th: 'ข้อมูลการทำเครื่องหมายอ่านแล้วไม่ถูกต้อง' },

  // modules/devices/routes.ts
  'devices.invalidRegisterPayload': {
    en: 'Invalid device registration payload',
    th: 'ข้อมูลการลงทะเบียนอุปกรณ์ไม่ถูกต้อง',
  },
  'devices.invalidUnregisterPayload': {
    en: 'Invalid device payload',
    th: 'ข้อมูลอุปกรณ์ไม่ถูกต้อง',
  },

  // modules/offers/routes.ts
  'offers.notPartOfOffer': { en: 'You are not part of this offer', th: 'คุณไม่ได้เป็นส่วนหนึ่งของข้อเสนอนี้' },
  'offers.invalidOfferData': { en: 'Invalid offer data', th: 'ข้อมูลข้อเสนอไม่ถูกต้อง' },
  'offers.cannotOfferOwnRequest': {
    en: 'You cannot make an offer on your own request',
    th: 'คุณไม่สามารถเสนอราคาให้กับรายการต้องการของตัวเองได้',
  },
  'offers.requestNotOpen': { en: 'This request is no longer open', th: 'รายการต้องการนี้ปิดรับข้อเสนอแล้ว' },
  'offers.wantSentToDifferentTrip': {
    en: 'This want was sent directly to a different trip',
    th: 'รายการต้องการนี้ถูกส่งตรงถึงทริปอื่นแล้ว',
  },
  'offers.tripNotYours': { en: 'That trip is not yours', th: 'ทริปนั้นไม่ใช่ของคุณ' },
  'offers.offerCannotBeAccepted': {
    en: 'This offer can no longer be accepted',
    th: 'ข้อเสนอนี้ไม่สามารถรับได้แล้ว',
  },
  'offers.requestAlreadyAccepted': {
    en: 'This request already has an accepted offer',
    th: 'รายการต้องการนี้มีข้อเสนอที่ถูกรับแล้ว',
  },
  'offers.invalidCounterPrice': { en: 'Invalid counter-offer price', th: 'ราคาต่อรองไม่ถูกต้อง' },
  'offers.offerNoLongerNegotiable': {
    en: 'This offer is no longer open for negotiation',
    th: 'ข้อเสนอนี้ไม่สามารถต่อรองได้แล้ว',
  },
  'offers.wantNoLongerOpen': { en: 'This want is no longer open', th: 'รายการต้องการนี้ปิดรับข้อเสนอแล้ว' },
  'offers.counterLimitReached': {
    en: "You've reached the counter-offer limit — accept the current price or decline",
    th: 'คุณต่อรองครบจำนวนครั้งที่กำหนดแล้ว — กรุณารับราคาปัจจุบันหรือปฏิเสธ',
  },
  'offers.offerNoLongerOpen': { en: 'This offer is no longer open', th: 'ข้อเสนอนี้ปิดรับแล้ว' },

  // modules/orders/delivery-routes.ts
  'delivery.receiptUrlRequired': { en: 'A receipt photo URL is required', th: 'ต้องแนบรูปใบเสร็จ' },
  'delivery.onlyTravelerCanUploadReceipt': {
    en: 'Only the traveler can upload a purchase receipt',
    th: 'เฉพาะนักเดินทางเท่านั้นที่อัปโหลดใบเสร็จการซื้อได้',
  },
  'delivery.paymentMustBeConfirmed': {
    en: 'Payment must be confirmed before recording a purchase',
    th: 'ต้องยืนยันการชำระเงินก่อนบันทึกการซื้อ',
  },
  'delivery.invalidDeliveryPayload': { en: 'Invalid delivery payload', th: 'ข้อมูลการจัดส่งไม่ถูกต้อง' },
  'delivery.onlyTravelerCanMarkDelivered': {
    en: 'Only the traveler can mark an order delivered',
    th: 'เฉพาะนักเดินทางเท่านั้นที่ทำเครื่องหมายว่าจัดส่งแล้วได้',
  },
  'delivery.uploadReceiptFirst': {
    en: 'Upload the purchase receipt before marking the order shipped',
    th: 'กรุณาอัปโหลดใบเสร็จการซื้อก่อนทำเครื่องหมายว่าจัดส่งแล้ว',
  },
  'delivery.invalidReleasePayload': { en: 'Invalid release payload', th: 'ข้อมูลการปล่อยเงินไม่ถูกต้อง' },
  'delivery.onlyShopperCanConfirmReceipt': {
    en: 'Only the shopper can confirm receipt',
    th: 'เฉพาะผู้ซื้อเท่านั้นที่ยืนยันการรับสินค้าได้',
  },
  'delivery.mustBeInTransit': {
    en: 'Order must be in transit before release',
    th: 'คำสั่งซื้อต้องอยู่ระหว่างจัดส่งก่อนจึงจะปล่อยเงินได้',
  },
  'delivery.orderHasOpenDispute': {
    en: 'This order has an open dispute — it must be resolved before payment can be released',
    th: 'คำสั่งซื้อนี้มีข้อพิพาทที่ยังไม่ได้รับการแก้ไข ต้องแก้ไขข้อพิพาทก่อนจึงจะปล่อยเงินได้',
  },
  'delivery.shippingProofUrlRequired': {
    en: 'A shipping proof photo URL is required',
    th: 'ต้องแนบรูปหลักฐานการจัดส่ง',
  },
  'delivery.onlyTravelerCanUploadShippingProof': {
    en: 'Only the traveler can upload shipping proof',
    th: 'เฉพาะนักเดินทางเท่านั้นที่อัปโหลดหลักฐานการจัดส่งได้',
  },
  'delivery.mustBeInTransitToAddShippingProof': {
    en: 'Order must be in transit to add shipping proof',
    th: 'คำสั่งซื้อต้องอยู่ระหว่างจัดส่งจึงจะแนบหลักฐานการจัดส่งได้',
  },
  'delivery.deliveryProofUrlRequired': {
    en: 'A photo of the item as received is required before releasing payment',
    th: 'ต้องแนบรูปสินค้าที่ได้รับก่อนปล่อยเงิน',
  },

  // modules/orders/routes.ts
  'orders.onlyShopperCanReportPayment': {
    en: 'Only the shopper can report a payment',
    th: 'เฉพาะผู้ซื้อเท่านั้นที่แจ้งการชำระเงินได้',
  },
  'orders.cancelledPaymentNotMadeInTime': {
    en: 'This order was cancelled because payment was not made in time',
    th: 'คำสั่งซื้อนี้ถูกยกเลิกเนื่องจากไม่ได้ชำระเงินภายในเวลาที่กำหนด',
  },
  'orders.notAwaitingPayment': { en: 'This order is not awaiting payment', th: 'คำสั่งซื้อนี้ไม่ได้รอการชำระเงิน' },

  // modules/requests/routes.ts
  'requests.invalidRequestData': { en: 'Invalid request data', th: 'ข้อมูลรายการต้องการไม่ถูกต้อง' },
  'requests.cannotRequestOwnTrip': {
    en: 'You cannot request from your own trip',
    th: 'คุณไม่สามารถขอจากทริปของตัวเองได้',
  },
  'requests.tripNotAcceptingRequests': {
    en: 'This trip is no longer accepting requests',
    th: 'ทริปนี้ไม่รับคำขอเพิ่มแล้ว',
  },
  'requests.onlyOpenCanBeEdited': {
    en: 'Only an open want can be edited',
    th: 'แก้ไขได้เฉพาะรายการต้องการที่ยังเปิดอยู่เท่านั้น',
  },
  'requests.invalidWantUpdate': { en: 'Invalid want update', th: 'ข้อมูลแก้ไขรายการต้องการไม่ถูกต้อง' },
  'requests.wantNotOpen': { en: 'Want is not open', th: 'รายการต้องการนี้ไม่ได้เปิดอยู่' },
  'requests.onlyCancelledOrCompletedCanBeCleared': {
    en: 'Only a cancelled or completed want can be cleared from your list',
    th: 'ลบออกจากลิสต์ได้เฉพาะรายการต้องการที่ยกเลิกหรือเสร็จสิ้นแล้วเท่านั้น',
  },

  // modules/reviews/routes.ts
  'reviews.invalidReview': { en: 'Invalid review', th: 'ข้อมูลรีวิวไม่ถูกต้อง' },
  'reviews.onlyAfterDelivered': {
    en: 'You can review once the order is delivered',
    th: 'รีวิวได้หลังจากคำสั่งซื้อจัดส่งสำเร็จแล้วเท่านั้น',
  },
  'reviews.alreadyReviewed': { en: 'You have already reviewed this order', th: 'คุณรีวิวคำสั่งซื้อนี้ไปแล้ว' },

  // modules/trips/routes.ts
  'trips.invalidTripData': { en: 'Invalid trip data', th: 'ข้อมูลทริปไม่ถูกต้อง' },
  'trips.onlyPublishedCanBeEdited': {
    en: 'Only a published trip can be edited',
    th: 'แก้ไขได้เฉพาะทริปที่เผยแพร่อยู่เท่านั้น',
  },
  'trips.invalidTripUpdate': { en: 'Invalid trip update', th: 'ข้อมูลแก้ไขทริปไม่ถูกต้อง' },
  'trips.returnAfterDeparture': {
    en: 'Return date must be after departure',
    th: 'วันเดินทางกลับต้องอยู่หลังวันออกเดินทาง',
  },
  'trips.notActive': { en: 'Trip is not active', th: 'ทริปนี้ไม่ได้ใช้งานอยู่' },
  'trips.hasActiveOrders': {
    en: 'This trip has an order still in progress — it must be delivered first',
    th: 'ทริปนี้มีคำสั่งซื้อที่กำลังดำเนินการอยู่ — ต้องจัดส่งให้เสร็จก่อน',
  },
  'trips.hasOffers': {
    en: 'This trip already has an offer on it — cancel it instead of deleting',
    th: 'ทริปนี้มีข้อเสนออยู่แล้ว — กรุณายกเลิกแทนการลบ',
  },
  'trips.onlyCancelledOrCompletedCanBeCleared': {
    en: 'Only a cancelled or completed trip can be cleared from your list',
    th: 'ลบออกจากลิสต์ได้เฉพาะทริปที่ยกเลิกหรือเสร็จสิ้นแล้วเท่านั้น',
  },

  // modules/uploads/routes.ts
  'uploads.multipartRequired': {
    en: 'Send the image as multipart/form-data',
    th: 'กรุณาส่งรูปภาพแบบ multipart/form-data',
  },
  'uploads.fileRequired': {
    en: 'Attach an image file in the "file" field',
    th: 'กรุณาแนบไฟล์รูปภาพในฟิลด์ "file"',
  },
  'uploads.invalidFormat': {
    en: 'Only JPEG, PNG or WebP images are allowed',
    th: 'รองรับเฉพาะไฟล์รูปภาพ JPEG, PNG หรือ WebP เท่านั้น',
  },
  'uploads.tooLarge': {
    en: (p) => `Image is larger than ${p.maxMb} MB`,
    th: (p) => `รูปภาพมีขนาดใหญ่เกิน ${p.maxMb} MB`,
  },
  'uploads.storeFailed': {
    en: 'Could not store the image. Try again.',
    th: 'ไม่สามารถบันทึกรูปภาพได้ กรุณาลองใหม่อีกครั้ง',
  },
  'uploads.signatureRequired': {
    en: 'This link has expired or is not valid for this file',
    th: 'ลิงก์นี้หมดอายุแล้วหรือไม่ถูกต้องสำหรับไฟล์นี้',
  },

  // modules/ops/routes.ts
  'ops.dbErrorOverview': { en: 'Failed to load ops overview', th: 'โหลดภาพรวมระบบไม่สำเร็จ' },
  'ops.dbErrorReconciliation': { en: 'Failed to load reconciliation', th: 'โหลดข้อมูลกระทบยอดไม่สำเร็จ' },
};

/** Returns the key itself if it's missing from the catalog — obvious in the
 * response/logs rather than silently falling back, so a typo is easy to spot. */
export function t(locale: SupportedLocale, key: string, params: Params = {}): string {
  const entry = MESSAGES[key];
  if (!entry) return key;
  const variant = entry[locale];
  return typeof variant === 'function' ? variant(params) : variant;
}
