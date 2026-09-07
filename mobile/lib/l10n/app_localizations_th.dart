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
  String get loginSubtitle => 'เข้าสู่ระบบเพื่อช้อปปิ้งต่อได้ทั่วโลก';

  @override
  String get errorLoginFailed => 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  String get loginNewToHiww => 'เพิ่งรู้จัก Hiww ใช่ไหม?';

  @override
  String get actionCreateAccount => 'สร้างบัญชี';

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
}
