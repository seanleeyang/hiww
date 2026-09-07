import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @tabBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse'**
  String get tabBrowse;

  /// No description provided for @tabMyTrips.
  ///
  /// In en, this message translates to:
  /// **'My Trips'**
  String get tabMyTrips;

  /// No description provided for @tabMyWants.
  ///
  /// In en, this message translates to:
  /// **'My Wants'**
  String get tabMyWants;

  /// No description provided for @tabOffers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get tabOffers;

  /// No description provided for @tabOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get tabOrders;

  /// No description provided for @tabInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get tabInbox;

  /// No description provided for @tooltipNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tooltipNotifications;

  /// No description provided for @tooltipAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tooltipAccount;

  /// No description provided for @fieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get fieldEmail;

  /// No description provided for @fieldPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get fieldPassword;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldFullName;

  /// No description provided for @fieldConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get fieldConfirmPassword;

  /// No description provided for @errorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get errorInvalidEmail;

  /// No description provided for @errorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get errorPasswordTooShort;

  /// No description provided for @errorEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Enter your full name'**
  String get errorEnterFullName;

  /// No description provided for @errorEnterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get errorEnterPhone;

  /// No description provided for @errorPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get errorPasswordsDontMatch;

  /// No description provided for @actionLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get actionLogIn;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Log in to keep shopping the world.'**
  String get loginSubtitle;

  /// No description provided for @errorLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not log in. Please try again.'**
  String get errorLoginFailed;

  /// No description provided for @loginNewToHiww.
  ///
  /// In en, this message translates to:
  /// **'New to Hiww?'**
  String get loginNewToHiww;

  /// No description provided for @actionCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get actionCreateAccount;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shop from travelers, or earn on trips you already take.'**
  String get registerSubtitle;

  /// No description provided for @errorUserExists.
  ///
  /// In en, this message translates to:
  /// **'An account with that email already exists.'**
  String get errorUserExists;

  /// No description provided for @errorRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not create your account. Please try again.'**
  String get errorRegisterFailed;

  /// No description provided for @registerIWantTo.
  ///
  /// In en, this message translates to:
  /// **'I want to…'**
  String get registerIWantTo;

  /// No description provided for @userTypeShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get userTypeShop;

  /// No description provided for @userTypeTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get userTypeTravel;

  /// No description provided for @userTypeBoth.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get userTypeBoth;

  /// No description provided for @actionCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get actionCreateAccountButton;

  /// No description provided for @registerAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get registerAlreadyHaveAccount;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your account'**
  String get verifyTitle;

  /// No description provided for @verifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit code to your email and phone number.'**
  String get verifySubtitle;

  /// No description provided for @verifyWrongDetails.
  ///
  /// In en, this message translates to:
  /// **'Wrong details?'**
  String get verifyWrongDetails;

  /// No description provided for @actionStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get actionStartOver;

  /// No description provided for @labelPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get labelPhone;

  /// No description provided for @devCodeNotice.
  ///
  /// In en, this message translates to:
  /// **'No SMS/email provider is set up yet — dev code {code} has been filled in for you.'**
  String devCodeNotice(String code);

  /// No description provided for @fieldOtpCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get fieldOtpCode;

  /// No description provided for @errorEnterOtpCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get errorEnterOtpCode;

  /// No description provided for @actionVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get actionVerify;

  /// No description provided for @actionResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get actionResendCode;

  /// No description provided for @actionSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get actionSending;

  /// No description provided for @infoNewCodeSent.
  ///
  /// In en, this message translates to:
  /// **'A new code was sent.'**
  String get infoNewCodeSent;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @accountCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get accountCompleteProfile;

  /// No description provided for @accountCompleteProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Add your phone number and delivery address — you\'ll need them before you can accept or make your first offer.'**
  String get accountCompleteProfileBody;

  /// No description provided for @actionAddDetails.
  ///
  /// In en, this message translates to:
  /// **'Add details'**
  String get actionAddDetails;

  /// No description provided for @sectionContactDelivery.
  ///
  /// In en, this message translates to:
  /// **'Contact & delivery'**
  String get sectionContactDelivery;

  /// No description provided for @accountAddPhone.
  ///
  /// In en, this message translates to:
  /// **'Add a phone number'**
  String get accountAddPhone;

  /// No description provided for @accountAddAddress.
  ///
  /// In en, this message translates to:
  /// **'Add a delivery address'**
  String get accountAddAddress;

  /// No description provided for @editProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfileTitle;

  /// No description provided for @fieldProfilePhoto.
  ///
  /// In en, this message translates to:
  /// **'Profile photo'**
  String get fieldProfilePhoto;

  /// No description provided for @fieldHomeCity.
  ///
  /// In en, this message translates to:
  /// **'Home city (optional)'**
  String get fieldHomeCity;

  /// No description provided for @contactDeliveryNote.
  ///
  /// In en, this message translates to:
  /// **'Required before your first order. Only visible to Hiww and the other person on an order — never shown publicly.'**
  String get contactDeliveryNote;

  /// No description provided for @fieldStreetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get fieldStreetAddress;

  /// No description provided for @fieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get fieldCity;

  /// No description provided for @fieldPostalCode.
  ///
  /// In en, this message translates to:
  /// **'Postal code'**
  String get fieldPostalCode;

  /// No description provided for @errorEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get errorEnterName;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @pilotTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual-money pilot'**
  String get pilotTitle;

  /// No description provided for @pilotBody.
  ///
  /// In en, this message translates to:
  /// **'Card payments are off during the pilot. You pay by bank transfer and the Hiww team confirms once the money lands.'**
  String get pilotBody;

  /// No description provided for @kycSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'ID check'**
  String get kycSectionTitle;

  /// No description provided for @kycVerified.
  ///
  /// In en, this message translates to:
  /// **'Your identity has been verified.'**
  String get kycVerified;

  /// No description provided for @kycUnverified.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity before completing an order. The Hiww team reviews submissions manually during the pilot.'**
  String get kycUnverified;

  /// No description provided for @actionUpdateIdDetails.
  ///
  /// In en, this message translates to:
  /// **'Update ID details'**
  String get actionUpdateIdDetails;

  /// No description provided for @actionSubmitIdDetails.
  ///
  /// In en, this message translates to:
  /// **'Submit ID details'**
  String get actionSubmitIdDetails;

  /// No description provided for @fieldDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get fieldDocumentType;

  /// No description provided for @docPassport.
  ///
  /// In en, this message translates to:
  /// **'Passport'**
  String get docPassport;

  /// No description provided for @docIdCard.
  ///
  /// In en, this message translates to:
  /// **'National ID card'**
  String get docIdCard;

  /// No description provided for @docDriversLicense.
  ///
  /// In en, this message translates to:
  /// **'Driver\'s licence'**
  String get docDriversLicense;

  /// No description provided for @fieldDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Document number'**
  String get fieldDocumentNumber;

  /// No description provided for @errorEnterDocumentNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter your document number'**
  String get errorEnterDocumentNumber;

  /// No description provided for @actionSubmitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get actionSubmitForReview;

  /// No description provided for @infoSubmittedForReview.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get infoSubmittedForReview;

  /// No description provided for @actionLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get actionLogOut;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'ไทย'**
  String get languageThai;

  /// No description provided for @deliveredCount.
  ///
  /// In en, this message translates to:
  /// **'{count} delivered'**
  String deliveredCount(int count);

  /// No description provided for @browseTabTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get browseTabTrips;

  /// No description provided for @browseTabWants.
  ///
  /// In en, this message translates to:
  /// **'Wants'**
  String get browseTabWants;

  /// No description provided for @actionPostATrip.
  ///
  /// In en, this message translates to:
  /// **'Post a trip'**
  String get actionPostATrip;

  /// No description provided for @actionPostAWant.
  ///
  /// In en, this message translates to:
  /// **'Post a want'**
  String get actionPostAWant;

  /// No description provided for @tooltipSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get tooltipSort;

  /// No description provided for @sortNewestPosted.
  ///
  /// In en, this message translates to:
  /// **'Newest posted'**
  String get sortNewestPosted;

  /// No description provided for @sortDepartingSoonest.
  ///
  /// In en, this message translates to:
  /// **'Departing soonest'**
  String get sortDepartingSoonest;

  /// No description provided for @sortNeededSoonest.
  ///
  /// In en, this message translates to:
  /// **'Needed soonest'**
  String get sortNeededSoonest;

  /// No description provided for @emptyNoTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips here yet'**
  String get emptyNoTripsTitle;

  /// No description provided for @emptyNoTripsMessage.
  ///
  /// In en, this message translates to:
  /// **'No travelers heading this way yet. Check back soon, or post your own trip if you\'re the one traveling.'**
  String get emptyNoTripsMessage;

  /// No description provided for @emptyNoWantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyNoWantsTitle;

  /// No description provided for @emptyNoWantsMessage.
  ///
  /// In en, this message translates to:
  /// **'No wants match this filter. Check back soon, or post a want of your own.'**
  String get emptyNoWantsMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
