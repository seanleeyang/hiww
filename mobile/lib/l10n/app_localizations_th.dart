// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get tabBrowse => 'สำรวจ';

  @override
  String get tabMyTrips => 'ทริปของฉัน';

  @override
  String get tabMyWants => 'รายการต้องการ';

  @override
  String get tabOffers => 'ข้อเสนอ';

  @override
  String get tabOrders => 'คำสั่งซื้อ';

  @override
  String get tabInbox => 'กล่องข้อความ';

  @override
  String get tooltipNotifications => 'การแจ้งเตือน';

  @override
  String get tooltipAccount => 'บัญชี';

  @override
  String get fieldEmail => 'อีเมล';

  @override
  String get fieldPassword => 'รหัสผ่าน';

  @override
  String get fieldFullName => 'ชื่อ-นามสกุล';

  @override
  String get fieldConfirmPassword => 'ยืนยันรหัสผ่าน';

  @override
  String get errorInvalidEmail => 'กรอกอีเมลให้ถูกต้อง';

  @override
  String get errorPasswordTooShort => 'อย่างน้อย 8 ตัวอักษร';

  @override
  String get errorEnterFullName => 'กรอกชื่อ-นามสกุลของคุณ';

  @override
  String get errorEnterPhone => 'กรอกเบอร์โทรศัพท์ของคุณ';

  @override
  String get errorPasswordsDontMatch => 'รหัสผ่านไม่ตรงกัน';

  @override
  String get actionLogIn => 'เข้าสู่ระบบ';

  @override
  String get loginTitle => 'ยินดีต้อนรับกลับ';

  @override
  String get loginSubtitle => 'เข้าสู่ระบบเพื่อช้อปทั่วโลก';

  @override
  String get errorLoginFailed => 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  String get loginNewToHiww => 'เพิ่งรู้จัก Hiww ใช่ไหม?';

  @override
  String get actionCreateAccount => 'สร้างบัญชี';

  @override
  String get actionForgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get forgotPasswordTitle => 'รีเซ็ตรหัสผ่านของคุณ';

  @override
  String get forgotPasswordSubtitle =>
      'กรอกอีเมลของคุณ แล้วเราจะส่งรหัสรีเซ็ตให้';

  @override
  String get actionSendCode => 'ส่งรหัส';

  @override
  String get errorForgotPasswordFailed =>
      'ส่งรหัสรีเซ็ตไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  String get resetPasswordTitle => 'กรอกรหัสรีเซ็ตของคุณ';

  @override
  String resetPasswordSubtitle(String email) {
    return 'เราได้ส่งรหัส 6 หลักไปที่ $email แล้ว';
  }

  @override
  String get fieldNewPassword => 'รหัสผ่านใหม่';

  @override
  String get actionResetPassword => 'รีเซ็ตรหัสผ่าน';

  @override
  String get errorResetPasswordFailed =>
      'รีเซ็ตรหัสผ่านไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  String get rememberedPassword => 'จำรหัสผ่านได้แล้วใช่ไหม?';

  @override
  String get registerTitle => 'สร้างบัญชีของคุณ';

  @override
  String get registerSubtitle =>
      'ช้อปจากนักเดินทาง หรือสร้างรายได้จากทริปที่คุณเดินทางอยู่แล้ว';

  @override
  String get errorUserExists => 'มีบัญชีที่ใช้อีเมลนี้อยู่แล้ว';

  @override
  String get errorRegisterFailed => 'สร้างบัญชีไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  String get registerIWantTo => 'ฉันต้องการ…';

  @override
  String get userTypeShop => 'ช้อป';

  @override
  String get userTypeTravel => 'เดินทาง';

  @override
  String get userTypeBoth => 'ทั้งสองอย่าง';

  @override
  String get actionCreateAccountButton => 'สร้างบัญชี';

  @override
  String get registerAlreadyHaveAccount => 'มีบัญชีอยู่แล้ว?';

  @override
  String get verifyTitle => 'ยืนยันบัญชีของคุณ';

  @override
  String get verifySubtitle =>
      'เราได้ส่งรหัส 6 หลักไปยังอีเมลและเบอร์โทรศัพท์ของคุณแล้ว';

  @override
  String get verifyWrongDetails => 'ข้อมูลไม่ถูกต้องใช่ไหม?';

  @override
  String get actionStartOver => 'เริ่มใหม่';

  @override
  String get labelPhone => 'โทรศัพท์';

  @override
  String devCodeNotice(String code) {
    return 'ยังไม่ได้ตั้งค่าผู้ให้บริการ SMS/อีเมล — เราได้กรอกรหัสทดสอบ $code ให้คุณแล้ว';
  }

  @override
  String get fieldOtpCode => 'รหัส 6 หลัก';

  @override
  String get errorEnterOtpCode => 'กรอกรหัส 6 หลัก';

  @override
  String get actionVerify => 'ยืนยัน';

  @override
  String get actionResendCode => 'ส่งรหัสอีกครั้ง';

  @override
  String get actionSending => 'กำลังส่ง…';

  @override
  String get infoNewCodeSent => 'ส่งรหัสใหม่แล้ว';

  @override
  String get accountTitle => 'บัญชี';

  @override
  String get actionEdit => 'แก้ไข';

  @override
  String get accountCompleteProfile => 'กรอกข้อมูลโปรไฟล์ให้ครบถ้วน';

  @override
  String get accountCompleteProfileBody =>
      'เพิ่มเบอร์โทรศัพท์และที่อยู่จัดส่ง — จำเป็นต้องมีก่อนที่คุณจะรับหรือเสนอข้อเสนอแรกได้';

  @override
  String get actionAddDetails => 'เพิ่มข้อมูล';

  @override
  String get sectionContactDelivery => 'ข้อมูลติดต่อและจัดส่ง';

  @override
  String get accountAddPhone => 'เพิ่มเบอร์โทรศัพท์';

  @override
  String get accountAddAddress => 'เพิ่มที่อยู่จัดส่ง';

  @override
  String get editProfileTitle => 'แก้ไขโปรไฟล์';

  @override
  String get fieldProfilePhoto => 'รูปโปรไฟล์';

  @override
  String get fieldHomeCity => 'เมืองที่อยู่ (ไม่บังคับ)';

  @override
  String get contactDeliveryNote =>
      'จำเป็นต้องกรอกก่อนคำสั่งซื้อแรกของคุณ ข้อมูลนี้ Hiww และอีกฝ่ายในคำสั่งซื้อเท่านั้นที่เห็นได้ — จะไม่แสดงต่อสาธารณะ';

  @override
  String get fieldStreetAddress => 'ที่อยู่ (ถนน)';

  @override
  String get fieldCity => 'เมือง';

  @override
  String get fieldPostalCode => 'รหัสไปรษณีย์';

  @override
  String get errorEnterName => 'กรอกชื่อของคุณ';

  @override
  String get actionSave => 'บันทึก';

  @override
  String get pilotTitle => 'โครงการนำร่องชำระเงินด้วยตนเอง';

  @override
  String get pilotBody =>
      'การชำระเงินด้วยบัตรถูกปิดใช้งานในช่วงนำร่อง คุณชำระเงินผ่านการโอนเงินธนาคาร และทีมงาน Hiww จะยืนยันเมื่อได้รับเงินแล้ว';

  @override
  String get kycSectionTitle => 'ตรวจสอบตัวตน';

  @override
  String get kycVerified => 'ยืนยันตัวตนของคุณเรียบร้อยแล้ว';

  @override
  String get kycUnverified =>
      'ยืนยันตัวตนก่อนทำคำสั่งซื้อให้เสร็จสมบูรณ์ ทีมงาน Hiww จะตรวจสอบเอกสารด้วยตนเองในช่วงนำร่อง';

  @override
  String get actionUpdateIdDetails => 'อัปเดตข้อมูลบัตร';

  @override
  String get actionSubmitIdDetails => 'ส่งข้อมูลบัตร';

  @override
  String get fieldDocumentType => 'ประเภทเอกสาร';

  @override
  String get docPassport => 'หนังสือเดินทาง';

  @override
  String get docIdCard => 'บัตรประจำตัวประชาชน';

  @override
  String get docDriversLicense => 'ใบขับขี่';

  @override
  String get fieldDocumentNumber => 'หมายเลขเอกสาร';

  @override
  String get errorEnterDocumentNumber => 'กรอกหมายเลขเอกสารของคุณ';

  @override
  String get actionSubmitForReview => 'ส่งเพื่อตรวจสอบ';

  @override
  String get infoSubmittedForReview => 'ส่งเพื่อตรวจสอบแล้ว';

  @override
  String get actionLogOut => 'ออกจากระบบ';

  @override
  String get settingsLanguage => 'ภาษา';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageThai => 'ไทย';

  @override
  String deliveredCount(int count) {
    return 'ส่งแล้ว $count รายการ';
  }

  @override
  String get browseTabTrips => 'ทริป';

  @override
  String get browseTabWants => 'รายการต้องการ';

  @override
  String get actionPostATrip => 'ลงทริป';

  @override
  String get actionPostAWant => 'ลงรายการต้องการ';

  @override
  String get tooltipSort => 'เรียงลำดับ';

  @override
  String get sortNewestPosted => 'ลงล่าสุด';

  @override
  String get sortDepartingSoonest => 'ออกเดินทางเร็วที่สุด';

  @override
  String get sortNeededSoonest => 'ต้องการเร็วที่สุด';

  @override
  String get emptyNoTripsTitle => 'ยังไม่มีทริปที่นี่';

  @override
  String get emptyNoTripsMessage =>
      'ยังไม่มีนักเดินทางไปทางนี้ ลองกลับมาดูใหม่ภายหลัง หรือลงทริปของคุณเองถ้าคุณกำลังจะเดินทาง';

  @override
  String get emptyNoWantsTitle => 'ยังไม่มีอะไรที่นี่';

  @override
  String get emptyNoWantsMessage =>
      'ไม่มีรายการต้องการที่ตรงกับตัวกรองนี้ ลองกลับมาดูใหม่ภายหลัง หรือลงรายการต้องการของคุณเอง';

  @override
  String get actionRemove => 'ลบ';

  @override
  String get actionCancel => 'ยกเลิก';

  @override
  String get dialogRemoveFromListBody =>
      'รายการนี้จะหายไปจากลิสต์ของคุณ ไม่กระทบประวัติของรายการ';

  @override
  String get tooltipRemoveFromList => 'ลบออกจากลิสต์ของคุณ';

  @override
  String get dialogRemoveTripTitle => 'ลบทริปนี้ใช่ไหม?';

  @override
  String get emptyMyTripsTitle => 'ยังไม่มีทริป';

  @override
  String get emptyMyTripsMessage =>
      'ลงทริปแล้วผู้ซื้อจะสามารถขอให้คุณซื้อของระหว่างทางได้';

  @override
  String get errorPickTravelDates => 'เลือกวันเดินทางของคุณ';

  @override
  String get errorEnterWeightAndItems => 'กรอกน้ำหนักและจำนวนสินค้าที่รับได้';

  @override
  String get errorReturnAfterDeparture =>
      'วันเดินทางกลับต้องอยู่หลังวันออกเดินทาง';

  @override
  String get dialogCancelTripTitle => 'ยกเลิกทริปนี้ใช่ไหม?';

  @override
  String get dialogCancelTripBody =>
      'ผู้ซื้อจะไม่สามารถค้นหาหรือเสนอราคาสำหรับทริปนี้ได้อีก และไม่สามารถย้อนกลับได้';

  @override
  String get actionKeepTrip => 'เก็บทริปไว้';

  @override
  String get actionCancelTrip => 'ยกเลิกทริป';

  @override
  String get errorTripHasActiveOrder =>
      'ทริปนี้มีคำสั่งซื้อที่กำลังดำเนินการอยู่ กรุณาใช้ \"แจ้งปัญหา\" ในคำสั่งซื้อนั้นแทน — การยกเลิกทริปจะไม่ช่วยแก้ปัญหานี้';

  @override
  String get tripEditTitle => 'แก้ไขทริป';

  @override
  String get labelFrom => 'จาก';

  @override
  String get labelTo => 'ไปยัง';

  @override
  String get labelDeparture => 'วันออกเดินทาง';

  @override
  String get labelReturn => 'วันเดินทางกลับ';

  @override
  String get fieldSpareWeightKg => 'น้ำหนักที่รับได้ (กก.)';

  @override
  String get fieldMaxItems => 'จำนวนสินค้าสูงสุด';

  @override
  String get fieldNoteOptional => 'หมายเหตุ (ไม่บังคับ)';

  @override
  String get hintNoteTrip => 'สิ่งที่คุณรับฝากได้ ความชอบส่วนตัว…';

  @override
  String get fieldCoverPhotoOptional => 'เพิ่มรูปปก (ไม่บังคับ)';

  @override
  String get actionSaveChanges => 'บันทึกการเปลี่ยนแปลง';

  @override
  String get actionPostTrip => 'ลงทริป';

  @override
  String get fieldCityOptional => 'เมือง (ไม่บังคับ)';

  @override
  String get tripDetailTitle => 'ทริป';

  @override
  String tripSpareCapacity(String weightKg, int maxItems) {
    return 'รับได้ $weightKg กก. · สูงสุด $maxItems ชิ้น';
  }

  @override
  String get actionRequestFromThisTrip => 'ขอจากทริปนี้';

  @override
  String get tripDetailOwnerNote =>
      'นี่คือทริปของคุณ ผู้ซื้อสามารถขอให้คุณซื้อของระหว่างเส้นทางนี้ได้';

  @override
  String get dialogRemoveWantTitle => 'ลบรายการต้องการนี้ใช่ไหม?';

  @override
  String get emptyMyWantsTitle => 'ยังไม่มีรายการต้องการ';

  @override
  String get emptyMyWantsMessage =>
      'ลงสิ่งที่คุณอยากให้ซื้อจากต่างประเทศ แล้วนักเดินทางจะเสนอราคาให้';

  @override
  String wantBudgetLine(String budget) {
    return 'งบประมาณ $budget';
  }

  @override
  String wantBuyInLine(String place) {
    return 'ซื้อที่ $place';
  }

  @override
  String get actionViewOrder => 'ดูคำสั่งซื้อ →';

  @override
  String get errorWantTitleTooShort => 'ตั้งชื่อรายการต้องการของคุณสั้นๆ';

  @override
  String get errorWantDetailsTooShort =>
      'เพิ่มรายละเอียด (อย่างน้อย 10 ตัวอักษร)';

  @override
  String get wantEditTitle => 'แก้ไขรายการต้องการ';

  @override
  String directRequestNotice(String name) {
    return 'ส่งตรงถึง $name — ไม่แสดงต่อสาธารณะ งบประมาณด้านล่างคือราคาเริ่มต้นของคุณ อีกฝ่ายสามารถรับ ต่อรอง หรือปฏิเสธได้';
  }

  @override
  String get fieldItem => 'สินค้า';

  @override
  String get hintItemExample => 'เช่น Nike Dunk Panda';

  @override
  String get fieldDetails => 'รายละเอียด';

  @override
  String get hintDetails => 'แบรนด์ รุ่น ไซซ์ สี ลิงก์';

  @override
  String get fieldPhotoOptional => 'เพิ่มรูปภาพ (ไม่บังคับ)';

  @override
  String get labelCategory => 'หมวดหมู่';

  @override
  String get labelBudget => 'งบประมาณ';

  @override
  String budgetTotalNote(num qty) {
    return 'ยอดรวมที่คุณคาดว่าจะจ่ายสำหรับทั้งหมด $qty ชิ้น';
  }

  @override
  String get labelQuantity => 'จำนวน';

  @override
  String get labelNeedBy => 'ต้องการภายใน';

  @override
  String get anyTime => 'เมื่อไหร่ก็ได้';

  @override
  String get labelBuyIn => 'ซื้อที่';

  @override
  String get hintCityExample => 'โตเกียว';

  @override
  String travelersHeadingSoon(num count, String country) {
    return 'มีนักเดินทาง $count คนกำลังจะไป $country เร็วๆ นี้';
  }

  @override
  String get actionSendRequest => 'ส่งคำขอ';

  @override
  String get actionPostMyWant => 'ลงรายการต้องการของฉัน';

  @override
  String get wantDetailTitle => 'รายการต้องการ';

  @override
  String get directRequestBadge =>
      'ส่งตรงถึงนักเดินทางคนเดียว — ไม่แสดงต่อสาธารณะ';

  @override
  String wantQuantityLine(int qty) {
    return 'จำนวน $qty';
  }

  @override
  String get actionMakeAnOffer => 'เสนอราคา';

  @override
  String get wantClosedNote => 'รายการต้องการนี้ไม่รับข้อเสนอแล้ว';

  @override
  String get dialogCancelWantTitle => 'ยกเลิกรายการต้องการนี้ใช่ไหม?';

  @override
  String get dialogCancelWantBody =>
      'นักเดินทางจะไม่เห็นหรือเสนอราคาให้ได้อีก และไม่สามารถย้อนกลับได้';

  @override
  String get actionKeepWant => 'เก็บรายการไว้';

  @override
  String get actionCancelWant => 'ยกเลิกรายการต้องการ';

  @override
  String get noOffersYetMessage =>
      'ยังไม่มีข้อเสนอ — นักเดินทางบนเส้นทางนี้จะเห็นรายการของคุณ';

  @override
  String get dialogAcceptOfferTitle => 'รับข้อเสนอนี้ใช่ไหม?';

  @override
  String dialogAcceptOfferBody(String price) {
    return 'คุณจะจ่าย $price สำหรับสินค้านี้ ระบบจะสร้างคำสั่งซื้อและให้คุณชำระเงิน';
  }

  @override
  String get actionAccept => 'รับข้อเสนอ';

  @override
  String offerCounteredTimes(num round) {
    return 'ต่อราคาแล้ว $round ครั้ง';
  }

  @override
  String get fallbackTraveler => 'นักเดินทาง';

  @override
  String get errorPickTripForOffer => 'เลือกทริปที่จะใช้เสนอราคา';

  @override
  String get errorEnterYourPrice => 'กรอกราคาของคุณ';

  @override
  String get errorPickDeliveryDate => 'เลือกวันที่จะส่งของ';

  @override
  String get infoOfferSent => 'ส่งข้อเสนอแล้ว';

  @override
  String get makeOfferTitle => 'เสนอราคา';

  @override
  String get emptyNeedTripTitle => 'คุณต้องมีทริปก่อน';

  @override
  String get emptyNeedTripMessage =>
      'ลงทริปที่คุณสามารถนำสินค้านี้ติดตัวไปได้ แล้วจึงเสนอราคา';

  @override
  String get labelWhichTrip => 'ทริปไหน';

  @override
  String get fieldYourPriceForGoods => 'ราคาของคุณสำหรับสินค้านี้';

  @override
  String get labelDeliverBy => 'ส่งภายใน';

  @override
  String get actionPickADate => 'เลือกวันที่';

  @override
  String get actionSendOffer => 'ส่งข้อเสนอ';

  @override
  String get emptyOffersTitle => 'ยังไม่มีข้อเสนอ';

  @override
  String get emptyOffersMessage =>
      'ข้อเสนอที่คุณส่งหรือได้รับ — ทั้งในฐานะผู้ซื้อหรือนักเดินทาง — จะแสดงที่นี่';

  @override
  String offerFromLabel(String name) {
    return 'จาก $name';
  }

  @override
  String offerToLabel(String name) {
    return 'ถึง $name';
  }

  @override
  String get fallbackATraveler => 'นักเดินทาง';

  @override
  String get fallbackAShopper => 'ผู้ซื้อ';

  @override
  String get fallbackOfferTitle => 'ข้อเสนอ';

  @override
  String get dialogCounterOfferTitle => 'ต่อรองราคา';

  @override
  String get fieldYourPrice => 'ราคาของคุณ';

  @override
  String get actionSend => 'ส่ง';

  @override
  String get waitingForResponse => 'รอการตอบกลับ';

  @override
  String waitingForResponseWithCountdown(String countdown) {
    return 'รอการตอบกลับ · $countdown';
  }

  @override
  String get wantNoLongerOpen => 'รายการต้องการนี้ปิดรับข้อเสนอแล้ว';

  @override
  String respondWithin(String countdown) {
    return 'ตอบกลับภายใน $countdown';
  }

  @override
  String actionAcceptPrice(String price) {
    return 'รับราคา $price';
  }

  @override
  String get actionCounter => 'ต่อรอง';

  @override
  String get actionDecline => 'ปฏิเสธ';

  @override
  String get actionDeclineFinalOffer => 'ปฏิเสธ (ข้อเสนอสุดท้าย)';

  @override
  String get emptyOrdersTitle => 'ยังไม่มีคำสั่งซื้อ';

  @override
  String get emptyOrdersMessage =>
      'เมื่อคุณรับข้อเสนอ หรือข้อเสนอของคุณถูกรับ คำสั่งซื้อจะปรากฏที่นี่ให้คุณติดตามได้ทุกขั้นตอน';

  @override
  String orderRelationBuying(String name) {
    return 'ซื้อจาก $name';
  }

  @override
  String orderRelationDelivering(String name) {
    return 'ส่งของให้ $name';
  }

  @override
  String get nextStepPayToStart => 'ชำระเงินเพื่อเริ่มดำเนินการ';

  @override
  String get nextStepWaitingForPayment => 'รอผู้ซื้อชำระเงิน';

  @override
  String get nextStepTravelerBuying => 'นักเดินทางกำลังซื้อสินค้าให้คุณ';

  @override
  String get nextStepBuyThenUpload => 'ซื้อสินค้าแล้วอัปโหลดใบเสร็จ';

  @override
  String get nextStepBoughtWaitShip =>
      'ซื้อแล้ว — นักเดินทางจะจัดส่งเมื่อกลับถึง';

  @override
  String get nextStepPostThenShip => 'ส่งพัสดุแล้วกดทำเครื่องหมายว่าจัดส่งแล้ว';

  @override
  String get nextStepOnWayConfirm => 'กำลังจัดส่ง — ยืนยันเมื่อได้รับสินค้า';

  @override
  String get nextStepShippedWaiting =>
      'จัดส่งแล้ว — รอผู้ซื้อยืนยันการรับสินค้า';

  @override
  String orderHashTitle(String code) {
    return 'คำสั่งซื้อ #$code';
  }

  @override
  String get roleCarrier => 'ผู้ขนส่ง';

  @override
  String get roleShopper => 'ผู้ซื้อ';

  @override
  String get actionOpenChat => 'เปิดแชท';

  @override
  String get actionReport => 'แจ้งปัญหา';

  @override
  String orderTotalWithFee(String total, String fee) {
    return '$total · ค่าธรรมเนียม $fee';
  }

  @override
  String get noteWaitingForShopperToPay => 'รอผู้ซื้อชำระเงิน';

  @override
  String payWithinOrCancel(String countdown) {
    return 'ชำระเงินภายใน $countdown ไม่เช่นนั้นคำสั่งซื้อจะถูกยกเลิกอัตโนมัติ';
  }

  @override
  String shopperHasTimeToPay(String countdown) {
    return 'ผู้ซื้อมีเวลา $countdown ในการชำระเงินก่อนคำสั่งซื้อจะถูกยกเลิกอัตโนมัติ';
  }

  @override
  String get howToPayTitle => 'วิธีชำระเงิน';

  @override
  String get contactHiwwForPayment =>
      'ติดต่อทีมงาน Hiww เพื่อจัดการการชำระเงิน';

  @override
  String amountReference(String total, String id) {
    return 'จำนวนเงิน $total  ·  เลขอ้างอิง $id';
  }

  @override
  String get noteToldUsPaid =>
      'คุณแจ้งว่าชำระเงินแล้ว เราจะยืนยันเมื่อได้รับเงิน';

  @override
  String get actionSentPayment => 'ฉันชำระเงินแล้ว';

  @override
  String get notePaymentConfirmedWaitingBuy =>
      'ยืนยันการชำระเงินแล้ว รอนักเดินทางซื้อสินค้า';

  @override
  String get notePaymentConfirmedUploadReceipt =>
      'ยืนยันการชำระเงินแล้ว ซื้อสินค้าแล้วอัปโหลดรูปใบเสร็จ — ให้เห็นวันที่และสินค้าชัดเจน จะปลดล็อกขั้นตอนการจัดส่ง';

  @override
  String get actionUploading => 'กำลังอัปโหลด…';

  @override
  String get actionUploadReceipt => 'อัปโหลดใบเสร็จการซื้อ';

  @override
  String get noteTravelerBoughtWillShip =>
      'นักเดินทางซื้อสินค้าของคุณแล้ว จะจัดส่งเมื่อกลับถึงประเทศต้นทาง';

  @override
  String get noteReceiptUploadedPostShip =>
      'อัปโหลดใบเสร็จแล้ว ส่งพัสดุเมื่อคุณถึงบ้าน แล้วกดทำเครื่องหมายว่าจัดส่งแล้ว';

  @override
  String get actionMarkShipped => 'ทำเครื่องหมายว่าจัดส่งแล้ว';

  @override
  String get noteShippedWaitingConfirm =>
      'จัดส่งแล้ว รอผู้ซื้อยืนยันการรับสินค้า';

  @override
  String get noteOnWayConfirm => 'กำลังจัดส่ง ยืนยันเมื่อคุณได้รับสินค้าแล้ว';

  @override
  String actionConfirmRelease(String total) {
    return 'ยืนยันและปล่อยเงิน $total';
  }

  @override
  String get ratedLabel => 'คุณให้คะแนน';

  @override
  String actionRateCounterparty(String name) {
    return 'ให้คะแนน $name';
  }

  @override
  String get fallbackTheOtherParty => 'อีกฝ่าย';

  @override
  String get noteCompletedThanks => 'เสร็จสมบูรณ์ ขอบคุณที่ใช้ Hiww!';

  @override
  String orderStatusFallback(String status) {
    return 'คำสั่งซื้อนี้อยู่ในสถานะ $status';
  }

  @override
  String get stageAcceptedTitle => 'รับข้อเสนอแล้ว';

  @override
  String get stageAcceptedHint => 'รับข้อเสนอแล้ว';

  @override
  String get stagePaidTitle => 'ชำระเงินแล้ว';

  @override
  String get stagePaidHint => 'ยืนยันการชำระเงินแล้ว';

  @override
  String get stageBoughtTitle => 'ซื้อแล้ว';

  @override
  String get stageBoughtHint => 'นักเดินทางซื้อสินค้าแล้ว';

  @override
  String get stageInTransitTitle => 'กำลังจัดส่ง';

  @override
  String get stageInTransitHint => 'กำลังเดินทางมาหาคุณ';

  @override
  String get stageDeliveredTitle => 'จัดส่งสำเร็จ';

  @override
  String get stageDeliveredHint => 'ยืนยันเพื่อปล่อยเงิน';

  @override
  String get errorTapStarToRate => 'แตะดาวเพื่อให้คะแนน';

  @override
  String get infoThanksForReview => 'ขอบคุณสำหรับรีวิว';

  @override
  String get infoPaymentReleased => 'ปล่อยเงินแล้ว — ขอบคุณ!';

  @override
  String get leaveReviewTitle => 'เขียนรีวิว';

  @override
  String get confirmAndReviewTitle => 'ยืนยันและรีวิว';

  @override
  String get fallbackTheTraveler => 'นักเดินทาง';

  @override
  String howWasName(String name) {
    return '$name เป็นอย่างไรบ้าง?';
  }

  @override
  String get hintShareHandover => 'เล่าว่าการส่งมอบเป็นอย่างไร (ไม่บังคับ)';

  @override
  String get actionSubmitReview => 'ส่งรีวิว';

  @override
  String releaseNoteToName(String name) {
    return 'การกระทำนี้จะปล่อยเงินที่ถือไว้ให้ $name';
  }

  @override
  String get errorDescribeProblem => 'กรุณาอธิบายปัญหา (อย่างน้อย 10 ตัวอักษร)';

  @override
  String get infoReported => 'แจ้งปัญหาแล้ว — ทีมงาน Hiww จะตรวจสอบ';

  @override
  String get reportProblemTitle => 'แจ้งปัญหา';

  @override
  String get reportProblemSubtitle =>
      'เงินจะถูกถือไว้ระหว่างที่ทีมงาน Hiww ตรวจสอบเรื่องนี้';

  @override
  String get hintWhatWentWrong => 'เกิดอะไรขึ้น?';

  @override
  String get actionSubmitReport => 'ส่งรายงาน';

  @override
  String trustReleasedTo(String total) {
    return 'ปล่อยเงินแล้ว — $total ให้นักเดินทาง';
  }

  @override
  String trustHolding(String total, String fee) {
    return 'Hiww ถือเงิน $total + ค่าธรรมเนียม $fee ไว้';
  }

  @override
  String get trustSettled => 'การชำระเงินสำหรับสินค้านี้เสร็จสมบูรณ์แล้ว';

  @override
  String get trustReleasedOnConfirm =>
      'จะปล่อยให้นักเดินทางเมื่อคุณยืนยันว่าได้รับสินค้าแล้ว';

  @override
  String get actionHowProtectionWorks => 'การคุ้มครองการชำระเงินทำงานอย่างไร';

  @override
  String get howProtectionStep1 => 'คุณชำระเงินให้ Hiww เมื่อรับข้อเสนอ';

  @override
  String get howProtectionStep2 =>
      'Hiww ถือเงินไว้ — นักเดินทางยังไม่ได้รับเงิน';

  @override
  String get howProtectionStep3 => 'นักเดินทางซื้อและจัดส่งสินค้าให้คุณ';

  @override
  String get howProtectionStep4 =>
      'คุณยืนยันว่าได้รับสินค้าแล้ว Hiww จึงปล่อยเงิน';

  @override
  String get howProtectionPilotNote =>
      'ในช่วงนำร่อง Hiww จะดำเนินการชำระเงินด้วยตนเองแทนการใช้ผู้ให้บริการบัตร หากมีปัญหาใดๆ ให้ใช้ \"แจ้งปัญหา\" และทีมงาน Hiww จะเข้ามาช่วยก่อนที่เงินจะเคลื่อนไหว';

  @override
  String get emptyInboxTitle => 'ยังไม่มีข้อความ';

  @override
  String get emptyInboxMessage =>
      'แชทจะปรากฏที่นี่เมื่อคุณมีคำสั่งซื้อกับนักเดินทางหรือผู้ซื้อ';

  @override
  String get fallbackConversation => 'การสนทนา';

  @override
  String get errorAttachPhoto => 'ไม่สามารถแนบรูปนี้ได้ ลองรูปอื่น';

  @override
  String get chatFallbackTitle => 'แชท';

  @override
  String get sayHello => 'ทักทายกันหน่อย 👋';

  @override
  String get tooltipRemovePhoto => 'ลบรูปภาพ';

  @override
  String get tooltipAttachPhoto => 'แนบรูปภาพ';

  @override
  String get uploadingPhoto => 'กำลังอัปโหลดรูปภาพ…';

  @override
  String get photoAttachedTapSend => 'แนบรูปภาพแล้ว กดส่งเพื่อแชร์';

  @override
  String get hintMessage => 'ข้อความ';

  @override
  String get tooltipSend => 'ส่ง';

  @override
  String get statusSent => 'ส่งแล้ว';

  @override
  String get statusRead => 'อ่านแล้ว';

  @override
  String get purchaseReceiptTitle => 'ใบเสร็จการซื้อ';
}
