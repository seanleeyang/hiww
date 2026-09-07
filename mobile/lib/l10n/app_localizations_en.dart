// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabBrowse => 'Browse';

  @override
  String get tabMyTrips => 'My Trips';

  @override
  String get tabMyWants => 'My Wants';

  @override
  String get tabOffers => 'Offers';

  @override
  String get tabOrders => 'Orders';

  @override
  String get tabInbox => 'Inbox';

  @override
  String get tooltipNotifications => 'Notifications';

  @override
  String get tooltipAccount => 'Account';

  @override
  String get fieldEmail => 'Email';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldConfirmPassword => 'Confirm password';

  @override
  String get errorInvalidEmail => 'Enter a valid email address';

  @override
  String get errorPasswordTooShort => 'At least 8 characters';

  @override
  String get errorEnterFullName => 'Enter your full name';

  @override
  String get errorEnterPhone => 'Enter your phone number';

  @override
  String get errorPasswordsDontMatch => 'Passwords don\'t match';

  @override
  String get actionLogIn => 'Log in';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Log in to keep shopping the world.';

  @override
  String get errorLoginFailed => 'Could not log in. Please try again.';

  @override
  String get loginNewToHiww => 'New to Hiww?';

  @override
  String get actionCreateAccount => 'Create an account';

  @override
  String get registerTitle => 'Create your account';

  @override
  String get registerSubtitle =>
      'Shop from travelers, or earn on trips you already take.';

  @override
  String get errorUserExists => 'An account with that email already exists.';

  @override
  String get errorRegisterFailed =>
      'Could not create your account. Please try again.';

  @override
  String get registerIWantTo => 'I want to…';

  @override
  String get userTypeShop => 'Shop';

  @override
  String get userTypeTravel => 'Travel';

  @override
  String get userTypeBoth => 'Both';

  @override
  String get actionCreateAccountButton => 'Create account';

  @override
  String get registerAlreadyHaveAccount => 'Already have an account?';

  @override
  String get verifyTitle => 'Verify your account';

  @override
  String get verifySubtitle =>
      'We\'ve sent a 6-digit code to your email and phone number.';

  @override
  String get verifyWrongDetails => 'Wrong details?';

  @override
  String get actionStartOver => 'Start over';

  @override
  String get labelPhone => 'Phone';

  @override
  String devCodeNotice(String code) {
    return 'No SMS/email provider is set up yet — dev code $code has been filled in for you.';
  }

  @override
  String get fieldOtpCode => '6-digit code';

  @override
  String get errorEnterOtpCode => 'Enter the 6-digit code';

  @override
  String get actionVerify => 'Verify';

  @override
  String get actionResendCode => 'Resend code';

  @override
  String get actionSending => 'Sending…';

  @override
  String get infoNewCodeSent => 'A new code was sent.';

  @override
  String get accountTitle => 'Account';

  @override
  String get actionEdit => 'Edit';

  @override
  String get accountCompleteProfile => 'Complete your profile';

  @override
  String get accountCompleteProfileBody =>
      'Add your phone number and delivery address — you\'ll need them before you can accept or make your first offer.';

  @override
  String get actionAddDetails => 'Add details';

  @override
  String get sectionContactDelivery => 'Contact & delivery';

  @override
  String get accountAddPhone => 'Add a phone number';

  @override
  String get accountAddAddress => 'Add a delivery address';

  @override
  String get editProfileTitle => 'Edit profile';

  @override
  String get fieldProfilePhoto => 'Profile photo';

  @override
  String get fieldHomeCity => 'Home city (optional)';

  @override
  String get contactDeliveryNote =>
      'Required before your first order. Only visible to Hiww and the other person on an order — never shown publicly.';

  @override
  String get fieldStreetAddress => 'Street address';

  @override
  String get fieldCity => 'City';

  @override
  String get fieldPostalCode => 'Postal code';

  @override
  String get errorEnterName => 'Enter your name';

  @override
  String get actionSave => 'Save';

  @override
  String get pilotTitle => 'Manual-money pilot';

  @override
  String get pilotBody =>
      'Card payments are off during the pilot. You pay by bank transfer and the Hiww team confirms once the money lands.';

  @override
  String get kycSectionTitle => 'ID check';

  @override
  String get kycVerified => 'Your identity has been verified.';

  @override
  String get kycUnverified =>
      'Verify your identity before completing an order. The Hiww team reviews submissions manually during the pilot.';

  @override
  String get actionUpdateIdDetails => 'Update ID details';

  @override
  String get actionSubmitIdDetails => 'Submit ID details';

  @override
  String get fieldDocumentType => 'Document type';

  @override
  String get docPassport => 'Passport';

  @override
  String get docIdCard => 'National ID card';

  @override
  String get docDriversLicense => 'Driver\'s licence';

  @override
  String get fieldDocumentNumber => 'Document number';

  @override
  String get errorEnterDocumentNumber => 'Enter your document number';

  @override
  String get actionSubmitForReview => 'Submit for review';

  @override
  String get infoSubmittedForReview => 'Submitted for review';

  @override
  String get actionLogOut => 'Log out';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageThai => 'ไทย';

  @override
  String deliveredCount(int count) {
    return '$count delivered';
  }

  @override
  String get browseTabTrips => 'Trips';

  @override
  String get browseTabWants => 'Wants';

  @override
  String get actionPostATrip => 'Post a trip';

  @override
  String get actionPostAWant => 'Post a want';

  @override
  String get tooltipSort => 'Sort';

  @override
  String get sortNewestPosted => 'Newest posted';

  @override
  String get sortDepartingSoonest => 'Departing soonest';

  @override
  String get sortNeededSoonest => 'Needed soonest';

  @override
  String get emptyNoTripsTitle => 'No trips here yet';

  @override
  String get emptyNoTripsMessage =>
      'No travelers heading this way yet. Check back soon, or post your own trip if you\'re the one traveling.';

  @override
  String get emptyNoWantsTitle => 'Nothing here yet';

  @override
  String get emptyNoWantsMessage =>
      'No wants match this filter. Check back soon, or post a want of your own.';
}
