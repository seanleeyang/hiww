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
  /// **'Home'**
  String get tabBrowse;

  /// No description provided for @tabMyTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
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

  /// No description provided for @ordersTabRequested.
  ///
  /// In en, this message translates to:
  /// **'{count} requested'**
  String ordersTabRequested(int count);

  /// No description provided for @ordersTabInTransit.
  ///
  /// In en, this message translates to:
  /// **'{count} in transit'**
  String ordersTabInTransit(int count);

  /// No description provided for @ordersTabReceived.
  ///
  /// In en, this message translates to:
  /// **'{count} received'**
  String ordersTabReceived(int count);

  /// No description provided for @ordersTabInactive.
  ///
  /// In en, this message translates to:
  /// **'{count} inactive'**
  String ordersTabInactive(int count);

  /// No description provided for @emptyOrdersBucketTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyOrdersBucketTitle;

  /// No description provided for @emptyOrdersBucketMessage.
  ///
  /// In en, this message translates to:
  /// **'Orders at this stage will show up here.'**
  String get emptyOrdersBucketMessage;

  /// No description provided for @tripsTabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tripsTabActive;

  /// No description provided for @tripsTabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get tripsTabPast;

  /// No description provided for @emptyTripsPastTitle.
  ///
  /// In en, this message translates to:
  /// **'No past trips'**
  String get emptyTripsPastTitle;

  /// No description provided for @emptyTripsPastMessage.
  ///
  /// In en, this message translates to:
  /// **'Trips that have ended or been cancelled show up here.'**
  String get emptyTripsPastMessage;

  /// No description provided for @inboxTabMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get inboxTabMessages;

  /// No description provided for @inboxTabNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get inboxTabNotifications;

  /// No description provided for @notificationsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get notificationsEmptyTitle;

  /// No description provided for @notificationsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Updates on your orders — payments, shipping, delivery — show up here.'**
  String get notificationsEmptyMessage;

  /// No description provided for @actionMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get actionMarkAllRead;

  /// No description provided for @tooltipSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tooltipSettings;

  /// No description provided for @tooltipAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get tooltipAccount;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

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
  /// **'Sign up'**
  String get actionCreateAccount;

  /// No description provided for @actionForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get actionForgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a reset code.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @actionSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get actionSendCode;

  /// No description provided for @errorForgotPasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send a reset code. Please try again.'**
  String get errorForgotPasswordFailed;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your reset code'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a 6-digit code to {email}.'**
  String resetPasswordSubtitle(String email);

  /// No description provided for @fieldNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get fieldNewPassword;

  /// No description provided for @actionResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get actionResetPassword;

  /// No description provided for @errorResetPasswordFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reset your password. Please try again.'**
  String get errorResetPasswordFailed;

  /// No description provided for @rememberedPassword.
  ///
  /// In en, this message translates to:
  /// **'Remembered your password?'**
  String get rememberedPassword;

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
  /// **'Sign up'**
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

  /// No description provided for @browseTabOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get browseTabOrder;

  /// No description provided for @browseTabTravel.
  ///
  /// In en, this message translates to:
  /// **'Travel'**
  String get browseTabTravel;

  /// No description provided for @actionPostATrip.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get actionPostATrip;

  /// No description provided for @actionPostAWant.
  ///
  /// In en, this message translates to:
  /// **'Create Order'**
  String get actionPostAWant;

  /// No description provided for @proTipTitle.
  ///
  /// In en, this message translates to:
  /// **'Pro tip'**
  String get proTipTitle;

  /// No description provided for @proTipCreateOrderBody.
  ///
  /// In en, this message translates to:
  /// **'Be sure to provide all product specifics about your order to be sure you receive the correct item.'**
  String get proTipCreateOrderBody;

  /// No description provided for @heroOrderGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, what would you like to order?'**
  String heroOrderGreetingNamed(String name);

  /// No description provided for @heroOrderGreetingGuest.
  ///
  /// In en, this message translates to:
  /// **'Hi there, what would you like to order?'**
  String get heroOrderGreetingGuest;

  /// No description provided for @heroOrderTagline.
  ///
  /// In en, this message translates to:
  /// **'Find travelers heading your way and get almost anything delivered.'**
  String get heroOrderTagline;

  /// No description provided for @heroOrderCta.
  ///
  /// In en, this message translates to:
  /// **'I\'m ready to start my order'**
  String get heroOrderCta;

  /// No description provided for @heroTravelGreetingNamed.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, ready to earn on your next trip?'**
  String heroTravelGreetingNamed(String name);

  /// No description provided for @heroTravelGreetingGuest.
  ///
  /// In en, this message translates to:
  /// **'Hi there, ready to earn on your next trip?'**
  String get heroTravelGreetingGuest;

  /// No description provided for @heroTravelTagline.
  ///
  /// In en, this message translates to:
  /// **'Carry a few extra items for shoppers on your route and get paid for it.'**
  String get heroTravelTagline;

  /// No description provided for @heroTravelCta.
  ///
  /// In en, this message translates to:
  /// **'Post your trip'**
  String get heroTravelCta;

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

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @verifyGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Before You Proceed'**
  String get verifyGateTitle;

  /// No description provided for @verifyGateBody.
  ///
  /// In en, this message translates to:
  /// **'Our mission is to build a safe community of shoppers and travelers who help each other shop across borders. To keep everyone protected, we\'ll need to confirm a few quick details before you continue.'**
  String get verifyGateBody;

  /// No description provided for @dialogRemoveFromListBody.
  ///
  /// In en, this message translates to:
  /// **'It disappears from your list. This does not affect its history.'**
  String get dialogRemoveFromListBody;

  /// No description provided for @tooltipRemoveFromList.
  ///
  /// In en, this message translates to:
  /// **'Remove from your list'**
  String get tooltipRemoveFromList;

  /// No description provided for @dialogRemoveTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this trip?'**
  String get dialogRemoveTripTitle;

  /// No description provided for @emptyMyTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips yet'**
  String get emptyMyTripsTitle;

  /// No description provided for @emptyMyTripsMessage.
  ///
  /// In en, this message translates to:
  /// **'Post a trip and shoppers can request items along your route.'**
  String get emptyMyTripsMessage;

  /// No description provided for @errorPickTravelDates.
  ///
  /// In en, this message translates to:
  /// **'Pick your travel dates'**
  String get errorPickTravelDates;

  /// No description provided for @errorEnterWeightAndItems.
  ///
  /// In en, this message translates to:
  /// **'Enter spare weight and item count'**
  String get errorEnterWeightAndItems;

  /// No description provided for @errorReturnAfterDeparture.
  ///
  /// In en, this message translates to:
  /// **'Return date must be after departure'**
  String get errorReturnAfterDeparture;

  /// No description provided for @dialogCancelTripTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this trip?'**
  String get dialogCancelTripTitle;

  /// No description provided for @dialogCancelTripBody.
  ///
  /// In en, this message translates to:
  /// **'Shoppers will no longer be able to find or offer against this trip. This can\'t be undone.'**
  String get dialogCancelTripBody;

  /// No description provided for @actionKeepTrip.
  ///
  /// In en, this message translates to:
  /// **'Keep trip'**
  String get actionKeepTrip;

  /// No description provided for @actionCancelTrip.
  ///
  /// In en, this message translates to:
  /// **'Cancel trip'**
  String get actionCancelTrip;

  /// No description provided for @errorTripHasActiveOrder.
  ///
  /// In en, this message translates to:
  /// **'This trip has an order still in progress. Use \"Report a problem\" on that order instead — cancelling the trip itself won\'t resolve it.'**
  String get errorTripHasActiveOrder;

  /// No description provided for @tripEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit trip'**
  String get tripEditTitle;

  /// No description provided for @labelFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get labelFrom;

  /// No description provided for @labelTo.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get labelTo;

  /// No description provided for @labelDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get labelDeparture;

  /// No description provided for @labelReturn.
  ///
  /// In en, this message translates to:
  /// **'Return'**
  String get labelReturn;

  /// No description provided for @fieldSpareWeightKg.
  ///
  /// In en, this message translates to:
  /// **'Spare weight (kg)'**
  String get fieldSpareWeightKg;

  /// No description provided for @fieldMaxItems.
  ///
  /// In en, this message translates to:
  /// **'Max items'**
  String get fieldMaxItems;

  /// No description provided for @fieldNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get fieldNoteOptional;

  /// No description provided for @hintNoteTrip.
  ///
  /// In en, this message translates to:
  /// **'What you can carry, preferences…'**
  String get hintNoteTrip;

  /// No description provided for @fieldCoverPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a cover photo (optional)'**
  String get fieldCoverPhotoOptional;

  /// No description provided for @actionSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get actionSaveChanges;

  /// No description provided for @actionPostTrip.
  ///
  /// In en, this message translates to:
  /// **'Add Trip'**
  String get actionPostTrip;

  /// No description provided for @fieldCityOptional.
  ///
  /// In en, this message translates to:
  /// **'City (optional)'**
  String get fieldCityOptional;

  /// No description provided for @heroTravelFormHeading.
  ///
  /// In en, this message translates to:
  /// **'Add your trip details to start earning money'**
  String get heroTravelFormHeading;

  /// No description provided for @labelTravelingFrom.
  ///
  /// In en, this message translates to:
  /// **'Traveling from'**
  String get labelTravelingFrom;

  /// No description provided for @labelTravelingTo.
  ///
  /// In en, this message translates to:
  /// **'Traveling to'**
  String get labelTravelingTo;

  /// No description provided for @labelTravelDates.
  ///
  /// In en, this message translates to:
  /// **'Travel dates'**
  String get labelTravelDates;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @locationSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get locationSearchTitle;

  /// No description provided for @locationRecentSection.
  ///
  /// In en, this message translates to:
  /// **'Recent locations'**
  String get locationRecentSection;

  /// No description provided for @tripDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get tripDetailTitle;

  /// No description provided for @tripSpareCapacity.
  ///
  /// In en, this message translates to:
  /// **'{weightKg} kg spare · up to {maxItems} items'**
  String tripSpareCapacity(String weightKg, int maxItems);

  /// No description provided for @actionRequestFromThisTrip.
  ///
  /// In en, this message translates to:
  /// **'Request from this trip'**
  String get actionRequestFromThisTrip;

  /// No description provided for @tripDetailOwnerNote.
  ///
  /// In en, this message translates to:
  /// **'This is your trip. Shoppers can request items along this route.'**
  String get tripDetailOwnerNote;

  /// No description provided for @dialogRemoveWantTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this want?'**
  String get dialogRemoveWantTitle;

  /// No description provided for @emptyMyWantsTitle.
  ///
  /// In en, this message translates to:
  /// **'No wants yet'**
  String get emptyMyWantsTitle;

  /// No description provided for @emptyMyWantsMessage.
  ///
  /// In en, this message translates to:
  /// **'Post what you want bought abroad and travelers will make offers.'**
  String get emptyMyWantsMessage;

  /// No description provided for @wantBudgetLine.
  ///
  /// In en, this message translates to:
  /// **'Budget {budget}'**
  String wantBudgetLine(String budget);

  /// No description provided for @wantBuyInLine.
  ///
  /// In en, this message translates to:
  /// **'Buy in {place}'**
  String wantBuyInLine(String place);

  /// No description provided for @wantDeliverToLine.
  ///
  /// In en, this message translates to:
  /// **'Deliver to {place}'**
  String wantDeliverToLine(String place);

  /// No description provided for @wantProductUrlLine.
  ///
  /// In en, this message translates to:
  /// **'Product URL: {url}'**
  String wantProductUrlLine(String url);

  /// No description provided for @actionViewOrder.
  ///
  /// In en, this message translates to:
  /// **'View order →'**
  String get actionViewOrder;

  /// No description provided for @errorWantTitleBlank.
  ///
  /// In en, this message translates to:
  /// **'Product Name cannot be left blank'**
  String get errorWantTitleBlank;

  /// No description provided for @errorWantTitleTooShort.
  ///
  /// In en, this message translates to:
  /// **'Product Name must be longer than 3 characters'**
  String get errorWantTitleTooShort;

  /// No description provided for @errorWantDetailsBlank.
  ///
  /// In en, this message translates to:
  /// **'Product Details cannot be left blank'**
  String get errorWantDetailsBlank;

  /// No description provided for @errorWantDetailsTooShort.
  ///
  /// In en, this message translates to:
  /// **'Product Details must be longer than 10 characters'**
  String get errorWantDetailsTooShort;

  /// No description provided for @wantEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit want'**
  String get wantEditTitle;

  /// No description provided for @directRequestNotice.
  ///
  /// In en, this message translates to:
  /// **'Sent directly to {name} — not shown publicly. Your budget below is your opening price; they can accept, counter, or decline.'**
  String directRequestNotice(String name);

  /// No description provided for @fieldProductUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Product URL (optional)'**
  String get fieldProductUrlOptional;

  /// No description provided for @hintProductUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste a link to the exact item'**
  String get hintProductUrl;

  /// No description provided for @fieldItem.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get fieldItem;

  /// No description provided for @hintItemExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. Nike Dunk Panda'**
  String get hintItemExample;

  /// No description provided for @fieldDetails.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get fieldDetails;

  /// No description provided for @hintDetails.
  ///
  /// In en, this message translates to:
  /// **'Brand, model, size, colour, links'**
  String get hintDetails;

  /// No description provided for @tooltipProductDetails.
  ///
  /// In en, this message translates to:
  /// **'Provide as much information about the product as you can, so that the traveler buys the correct item.'**
  String get tooltipProductDetails;

  /// No description provided for @fieldPhotoOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a photo (optional)'**
  String get fieldPhotoOptional;

  /// No description provided for @fieldPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get fieldPhoto;

  /// No description provided for @errorPhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of the item'**
  String get errorPhotoRequired;

  /// No description provided for @labelCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get labelCategory;

  /// No description provided for @labelBudget.
  ///
  /// In en, this message translates to:
  /// **'Budget'**
  String get labelBudget;

  /// No description provided for @budgetTotalNote.
  ///
  /// In en, this message translates to:
  /// **'Total you expect to pay, for all {qty, plural, one{{qty} item} other{{qty} items}}.'**
  String budgetTotalNote(num qty);

  /// No description provided for @labelQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get labelQuantity;

  /// No description provided for @labelNeedBy.
  ///
  /// In en, this message translates to:
  /// **'Need by'**
  String get labelNeedBy;

  /// No description provided for @tooltipNeedBy.
  ///
  /// In en, this message translates to:
  /// **'The longer period you are ready to wait, the more offers you receive and can choose from.'**
  String get tooltipNeedBy;

  /// No description provided for @anyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get anyTime;

  /// No description provided for @labelBuyIn.
  ///
  /// In en, this message translates to:
  /// **'Buy in'**
  String get labelBuyIn;

  /// No description provided for @labelDeliverTo.
  ///
  /// In en, this message translates to:
  /// **'Deliver to'**
  String get labelDeliverTo;

  /// No description provided for @labelCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get labelCountry;

  /// No description provided for @selectOption.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectOption;

  /// No description provided for @cityOptionAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get cityOptionAny;

  /// No description provided for @cityOptionOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get cityOptionOthers;

  /// No description provided for @hintCityCustom.
  ///
  /// In en, this message translates to:
  /// **'Enter your city'**
  String get hintCityCustom;

  /// No description provided for @errorBuyInCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Buy in (Country) cannot be left blank'**
  String get errorBuyInCountryRequired;

  /// No description provided for @errorBuyInCityRequired.
  ///
  /// In en, this message translates to:
  /// **'Buy in (City) cannot be left blank'**
  String get errorBuyInCityRequired;

  /// No description provided for @errorDeliverToCountryRequired.
  ///
  /// In en, this message translates to:
  /// **'Deliver to (Country) cannot be left blank'**
  String get errorDeliverToCountryRequired;

  /// No description provided for @errorDeliverToCityRequired.
  ///
  /// In en, this message translates to:
  /// **'Deliver to (City) cannot be left blank'**
  String get errorDeliverToCityRequired;

  /// No description provided for @hintCityExample.
  ///
  /// In en, this message translates to:
  /// **'Tokyo'**
  String get hintCityExample;

  /// No description provided for @travelersHeadingSoon.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} traveler} other{{count} travelers}} heading to {country} soon'**
  String travelersHeadingSoon(num count, String country);

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @summaryScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summaryScreenTitle;

  /// No description provided for @actionSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get actionSendRequest;

  /// No description provided for @actionPostMyWant.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get actionPostMyWant;

  /// No description provided for @wantDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Want'**
  String get wantDetailTitle;

  /// No description provided for @directRequestBadge.
  ///
  /// In en, this message translates to:
  /// **'Sent directly to one traveler — not shown publicly'**
  String get directRequestBadge;

  /// No description provided for @wantQuantityLine.
  ///
  /// In en, this message translates to:
  /// **'Quantity {qty}'**
  String wantQuantityLine(int qty);

  /// No description provided for @actionMakeAnOffer.
  ///
  /// In en, this message translates to:
  /// **'Make an offer'**
  String get actionMakeAnOffer;

  /// No description provided for @wantClosedNote.
  ///
  /// In en, this message translates to:
  /// **'This want is no longer taking offers.'**
  String get wantClosedNote;

  /// No description provided for @dialogCancelWantTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this want?'**
  String get dialogCancelWantTitle;

  /// No description provided for @dialogCancelWantBody.
  ///
  /// In en, this message translates to:
  /// **'Travelers will no longer see it or be able to offer on it. This can\'t be undone.'**
  String get dialogCancelWantBody;

  /// No description provided for @actionKeepWant.
  ///
  /// In en, this message translates to:
  /// **'Keep want'**
  String get actionKeepWant;

  /// No description provided for @actionCancelWant.
  ///
  /// In en, this message translates to:
  /// **'Cancel want'**
  String get actionCancelWant;

  /// No description provided for @noOffersYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No offers yet — travelers on this route will see it.'**
  String get noOffersYetMessage;

  /// No description provided for @dialogAcceptOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Accept this offer?'**
  String get dialogAcceptOfferTitle;

  /// No description provided for @dialogAcceptOfferBody.
  ///
  /// In en, this message translates to:
  /// **'You will pay {price} for the goods. An order is created and you\'ll be asked to pay.'**
  String dialogAcceptOfferBody(String price);

  /// No description provided for @priceBreakdownProductPrice.
  ///
  /// In en, this message translates to:
  /// **'Product Price'**
  String get priceBreakdownProductPrice;

  /// No description provided for @priceBreakdownTravellerReward.
  ///
  /// In en, this message translates to:
  /// **'Traveller Reward'**
  String get priceBreakdownTravellerReward;

  /// No description provided for @priceBreakdownServiceFee.
  ///
  /// In en, this message translates to:
  /// **'Service & Protection Fee'**
  String get priceBreakdownServiceFee;

  /// No description provided for @priceBreakdownTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get priceBreakdownTotal;

  /// No description provided for @travellerBreakdownProductValue.
  ///
  /// In en, this message translates to:
  /// **'Product Value'**
  String get travellerBreakdownProductValue;

  /// No description provided for @travellerBreakdownYourReward.
  ///
  /// In en, this message translates to:
  /// **'Your Reward'**
  String get travellerBreakdownYourReward;

  /// No description provided for @travellerBreakdownYouReceive.
  ///
  /// In en, this message translates to:
  /// **'You Receive'**
  String get travellerBreakdownYouReceive;

  /// No description provided for @actionAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get actionAccept;

  /// No description provided for @offerCounteredTimes.
  ///
  /// In en, this message translates to:
  /// **'Countered {round, plural, one{{round} time} other{{round} times}}'**
  String offerCounteredTimes(num round);

  /// No description provided for @fallbackTraveler.
  ///
  /// In en, this message translates to:
  /// **'Traveler'**
  String get fallbackTraveler;

  /// No description provided for @errorPickTripForOffer.
  ///
  /// In en, this message translates to:
  /// **'Pick which trip this is for'**
  String get errorPickTripForOffer;

  /// No description provided for @errorEnterYourPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter your price'**
  String get errorEnterYourPrice;

  /// No description provided for @errorPickDeliveryDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a delivery date'**
  String get errorPickDeliveryDate;

  /// No description provided for @infoOfferSent.
  ///
  /// In en, this message translates to:
  /// **'Offer sent'**
  String get infoOfferSent;

  /// No description provided for @makeOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Make an offer'**
  String get makeOfferTitle;

  /// No description provided for @emptyNeedTripTitle.
  ///
  /// In en, this message translates to:
  /// **'You need a trip first'**
  String get emptyNeedTripTitle;

  /// No description provided for @emptyNeedTripMessage.
  ///
  /// In en, this message translates to:
  /// **'Post a trip you can carry this item on, then make your offer.'**
  String get emptyNeedTripMessage;

  /// No description provided for @labelWhichTrip.
  ///
  /// In en, this message translates to:
  /// **'Which trip'**
  String get labelWhichTrip;

  /// No description provided for @fieldYourPriceForGoods.
  ///
  /// In en, this message translates to:
  /// **'Your price for the goods'**
  String get fieldYourPriceForGoods;

  /// No description provided for @labelDeliverBy.
  ///
  /// In en, this message translates to:
  /// **'Deliver by'**
  String get labelDeliverBy;

  /// No description provided for @actionPickADate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get actionPickADate;

  /// No description provided for @actionSendOffer.
  ///
  /// In en, this message translates to:
  /// **'Send offer'**
  String get actionSendOffer;

  /// No description provided for @emptyOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'No offers yet'**
  String get emptyOffersTitle;

  /// No description provided for @emptyOffersMessage.
  ///
  /// In en, this message translates to:
  /// **'Offers you make or receive — as a shopper or a traveler — show up here.'**
  String get emptyOffersMessage;

  /// No description provided for @offerFromLabel.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String offerFromLabel(String name);

  /// No description provided for @offerToLabel.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String offerToLabel(String name);

  /// No description provided for @fallbackATraveler.
  ///
  /// In en, this message translates to:
  /// **'a traveler'**
  String get fallbackATraveler;

  /// No description provided for @fallbackAShopper.
  ///
  /// In en, this message translates to:
  /// **'a shopper'**
  String get fallbackAShopper;

  /// No description provided for @fallbackOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Offer'**
  String get fallbackOfferTitle;

  /// No description provided for @dialogCounterOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Counter-offer'**
  String get dialogCounterOfferTitle;

  /// No description provided for @fieldYourPrice.
  ///
  /// In en, this message translates to:
  /// **'Your price'**
  String get fieldYourPrice;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @waitingForResponse.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a response'**
  String get waitingForResponse;

  /// No description provided for @waitingForResponseWithCountdown.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a response · {countdown}'**
  String waitingForResponseWithCountdown(String countdown);

  /// No description provided for @wantNoLongerOpen.
  ///
  /// In en, this message translates to:
  /// **'This want is no longer open'**
  String get wantNoLongerOpen;

  /// No description provided for @respondWithin.
  ///
  /// In en, this message translates to:
  /// **'Respond within {countdown}'**
  String respondWithin(String countdown);

  /// No description provided for @actionAcceptPrice.
  ///
  /// In en, this message translates to:
  /// **'Accept {price}'**
  String actionAcceptPrice(String price);

  /// No description provided for @actionCounter.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get actionCounter;

  /// No description provided for @actionDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get actionDecline;

  /// No description provided for @actionDeclineFinalOffer.
  ///
  /// In en, this message translates to:
  /// **'Decline (final offer)'**
  String get actionDeclineFinalOffer;

  /// No description provided for @emptyOrdersTitle.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get emptyOrdersTitle;

  /// No description provided for @emptyOrdersMessage.
  ///
  /// In en, this message translates to:
  /// **'When you accept an offer or one of your offers is accepted, the order shows up here so you can track every step.'**
  String get emptyOrdersMessage;

  /// No description provided for @orderRelationBuying.
  ///
  /// In en, this message translates to:
  /// **'Buying from {name}'**
  String orderRelationBuying(String name);

  /// No description provided for @orderRelationDelivering.
  ///
  /// In en, this message translates to:
  /// **'Delivering for {name}'**
  String orderRelationDelivering(String name);

  /// No description provided for @nextStepPayToStart.
  ///
  /// In en, this message translates to:
  /// **'Pay to get things moving'**
  String get nextStepPayToStart;

  /// No description provided for @nextStepWaitingForPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the shopper to pay'**
  String get nextStepWaitingForPayment;

  /// No description provided for @nextStepTravelerBuying.
  ///
  /// In en, this message translates to:
  /// **'Traveler is buying your item'**
  String get nextStepTravelerBuying;

  /// No description provided for @nextStepBuyThenUpload.
  ///
  /// In en, this message translates to:
  /// **'Buy the item, then upload the receipt'**
  String get nextStepBuyThenUpload;

  /// No description provided for @nextStepBoughtWaitShip.
  ///
  /// In en, this message translates to:
  /// **'Bought — traveler will ship once they’re back'**
  String get nextStepBoughtWaitShip;

  /// No description provided for @nextStepPostThenShip.
  ///
  /// In en, this message translates to:
  /// **'Post the item, then mark it shipped'**
  String get nextStepPostThenShip;

  /// No description provided for @nextStepOnWayConfirm.
  ///
  /// In en, this message translates to:
  /// **'On its way — confirm when it arrives'**
  String get nextStepOnWayConfirm;

  /// No description provided for @nextStepShippedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Shipped — waiting for the shopper to confirm receipt'**
  String get nextStepShippedWaiting;

  /// No description provided for @orderHashTitle.
  ///
  /// In en, this message translates to:
  /// **'Order #{code}'**
  String orderHashTitle(String code);

  /// No description provided for @roleCarrier.
  ///
  /// In en, this message translates to:
  /// **'Carrier'**
  String get roleCarrier;

  /// No description provided for @roleShopper.
  ///
  /// In en, this message translates to:
  /// **'Shopper'**
  String get roleShopper;

  /// No description provided for @actionOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Open chat'**
  String get actionOpenChat;

  /// No description provided for @actionReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get actionReport;

  /// No description provided for @orderTotalWithFee.
  ///
  /// In en, this message translates to:
  /// **'{total} · {fee} fee'**
  String orderTotalWithFee(String total, String fee);

  /// No description provided for @noteWaitingForShopperToPay.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the shopper to pay.'**
  String get noteWaitingForShopperToPay;

  /// No description provided for @payWithinOrCancel.
  ///
  /// In en, this message translates to:
  /// **'Pay within {countdown} or the order is cancelled automatically.'**
  String payWithinOrCancel(String countdown);

  /// No description provided for @shopperHasTimeToPay.
  ///
  /// In en, this message translates to:
  /// **'Shopper has {countdown} to pay before the order auto-cancels.'**
  String shopperHasTimeToPay(String countdown);

  /// No description provided for @howToPayTitle.
  ///
  /// In en, this message translates to:
  /// **'How to pay'**
  String get howToPayTitle;

  /// No description provided for @contactHiwwForPayment.
  ///
  /// In en, this message translates to:
  /// **'Contact the Hiww team to arrange payment.'**
  String get contactHiwwForPayment;

  /// No description provided for @amountReference.
  ///
  /// In en, this message translates to:
  /// **'Amount {total}  ·  reference {id}'**
  String amountReference(String total, String id);

  /// No description provided for @noteToldUsPaid.
  ///
  /// In en, this message translates to:
  /// **'You\'ve told us you paid. We\'ll confirm once it lands.'**
  String get noteToldUsPaid;

  /// No description provided for @actionSentPayment.
  ///
  /// In en, this message translates to:
  /// **'I\'ve sent the payment'**
  String get actionSentPayment;

  /// No description provided for @notePaymentConfirmedWaitingBuy.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed. Waiting for the traveler to buy the item.'**
  String get notePaymentConfirmedWaitingBuy;

  /// No description provided for @notePaymentConfirmedUploadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed. Buy the item, then upload a photo of the shop receipt — clear date and the item in frame. That unlocks the shipping step.'**
  String get notePaymentConfirmedUploadReceipt;

  /// No description provided for @actionUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get actionUploading;

  /// No description provided for @actionUploadReceipt.
  ///
  /// In en, this message translates to:
  /// **'Upload purchase receipt'**
  String get actionUploadReceipt;

  /// No description provided for @noteTravelerBoughtWillShip.
  ///
  /// In en, this message translates to:
  /// **'The traveler bought your item. They’ll ship it once they’re back in the origin country.'**
  String get noteTravelerBoughtWillShip;

  /// No description provided for @noteReceiptUploadedPostShip.
  ///
  /// In en, this message translates to:
  /// **'Receipt uploaded. Post the item when you’re home, then mark it shipped.'**
  String get noteReceiptUploadedPostShip;

  /// No description provided for @actionMarkShipped.
  ///
  /// In en, this message translates to:
  /// **'Mark as shipped'**
  String get actionMarkShipped;

  /// No description provided for @noteShippedWaitingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Shipped. Waiting for the shopper to confirm receipt.'**
  String get noteShippedWaitingConfirm;

  /// No description provided for @noteOnWayConfirm.
  ///
  /// In en, this message translates to:
  /// **'On the way. Confirm once you have it in hand.'**
  String get noteOnWayConfirm;

  /// No description provided for @actionConfirmRelease.
  ///
  /// In en, this message translates to:
  /// **'Confirm & release {total}'**
  String actionConfirmRelease(String total);

  /// No description provided for @ratedLabel.
  ///
  /// In en, this message translates to:
  /// **'You rated'**
  String get ratedLabel;

  /// No description provided for @actionRateCounterparty.
  ///
  /// In en, this message translates to:
  /// **'Rate {name}'**
  String actionRateCounterparty(String name);

  /// No description provided for @fallbackTheOtherParty.
  ///
  /// In en, this message translates to:
  /// **'the other party'**
  String get fallbackTheOtherParty;

  /// No description provided for @noteCompletedThanks.
  ///
  /// In en, this message translates to:
  /// **'Completed. Thanks for using Hiww!'**
  String get noteCompletedThanks;

  /// No description provided for @orderStatusFallback.
  ///
  /// In en, this message translates to:
  /// **'This order is {status}.'**
  String orderStatusFallback(String status);

  /// No description provided for @stageAcceptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get stageAcceptedTitle;

  /// No description provided for @stageAcceptedHint.
  ///
  /// In en, this message translates to:
  /// **'Offer accepted'**
  String get stageAcceptedHint;

  /// No description provided for @stagePaidTitle.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get stagePaidTitle;

  /// No description provided for @stagePaidHint.
  ///
  /// In en, this message translates to:
  /// **'Payment confirmed'**
  String get stagePaidHint;

  /// No description provided for @stageBoughtTitle.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get stageBoughtTitle;

  /// No description provided for @stageBoughtHint.
  ///
  /// In en, this message translates to:
  /// **'Traveler bought the item'**
  String get stageBoughtHint;

  /// No description provided for @stageInTransitTitle.
  ///
  /// In en, this message translates to:
  /// **'In transit'**
  String get stageInTransitTitle;

  /// No description provided for @stageInTransitHint.
  ///
  /// In en, this message translates to:
  /// **'On the way to you'**
  String get stageInTransitHint;

  /// No description provided for @stageDeliveredTitle.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get stageDeliveredTitle;

  /// No description provided for @stageDeliveredHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm to release payment'**
  String get stageDeliveredHint;

  /// No description provided for @errorTapStarToRate.
  ///
  /// In en, this message translates to:
  /// **'Tap a star to rate'**
  String get errorTapStarToRate;

  /// No description provided for @infoThanksForReview.
  ///
  /// In en, this message translates to:
  /// **'Thanks for the review'**
  String get infoThanksForReview;

  /// No description provided for @infoPaymentReleased.
  ///
  /// In en, this message translates to:
  /// **'Payment released — thank you!'**
  String get infoPaymentReleased;

  /// No description provided for @leaveReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave a review'**
  String get leaveReviewTitle;

  /// No description provided for @confirmAndReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm & review'**
  String get confirmAndReviewTitle;

  /// No description provided for @fallbackTheTraveler.
  ///
  /// In en, this message translates to:
  /// **'the traveler'**
  String get fallbackTheTraveler;

  /// No description provided for @howWasName.
  ///
  /// In en, this message translates to:
  /// **'How was {name}?'**
  String howWasName(String name);

  /// No description provided for @hintShareHandover.
  ///
  /// In en, this message translates to:
  /// **'Share how the handover went (optional)'**
  String get hintShareHandover;

  /// No description provided for @actionSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get actionSubmitReview;

  /// No description provided for @releaseNoteToName.
  ///
  /// In en, this message translates to:
  /// **'This releases the held payment to {name}.'**
  String releaseNoteToName(String name);

  /// No description provided for @errorDescribeProblem.
  ///
  /// In en, this message translates to:
  /// **'Please describe the problem (at least 10 characters)'**
  String get errorDescribeProblem;

  /// No description provided for @infoReported.
  ///
  /// In en, this message translates to:
  /// **'Reported — the Hiww team will look into it'**
  String get infoReported;

  /// No description provided for @reportProblemTitle.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblemTitle;

  /// No description provided for @reportProblemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Money stays held while the Hiww team reviews this.'**
  String get reportProblemSubtitle;

  /// No description provided for @hintWhatWentWrong.
  ///
  /// In en, this message translates to:
  /// **'What went wrong?'**
  String get hintWhatWentWrong;

  /// No description provided for @actionSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get actionSubmitReport;

  /// No description provided for @trustReleasedTo.
  ///
  /// In en, this message translates to:
  /// **'Released — {total} to the traveler'**
  String trustReleasedTo(String total);

  /// No description provided for @trustHolding.
  ///
  /// In en, this message translates to:
  /// **'Hiww is holding {total} + {fee} fee'**
  String trustHolding(String total, String fee);

  /// No description provided for @trustHoldingTotal.
  ///
  /// In en, this message translates to:
  /// **'Hiww is holding {total}'**
  String trustHoldingTotal(String total);

  /// No description provided for @trustSettled.
  ///
  /// In en, this message translates to:
  /// **'Payment for these goods has been settled.'**
  String get trustSettled;

  /// No description provided for @trustReleasedOnConfirm.
  ///
  /// In en, this message translates to:
  /// **'Released to the traveler when you confirm you have the item.'**
  String get trustReleasedOnConfirm;

  /// No description provided for @actionHowProtectionWorks.
  ///
  /// In en, this message translates to:
  /// **'How payment protection works'**
  String get actionHowProtectionWorks;

  /// No description provided for @howProtectionStep1.
  ///
  /// In en, this message translates to:
  /// **'You pay Hiww when you accept an offer.'**
  String get howProtectionStep1;

  /// No description provided for @howProtectionStep2.
  ///
  /// In en, this message translates to:
  /// **'Hiww holds the money — the traveler is not paid yet.'**
  String get howProtectionStep2;

  /// No description provided for @howProtectionStep3.
  ///
  /// In en, this message translates to:
  /// **'The traveler buys and ships your item.'**
  String get howProtectionStep3;

  /// No description provided for @howProtectionStep4.
  ///
  /// In en, this message translates to:
  /// **'You confirm you received it, and Hiww releases the payment.'**
  String get howProtectionStep4;

  /// No description provided for @howProtectionPilotNote.
  ///
  /// In en, this message translates to:
  /// **'During the pilot, Hiww settles payments by hand rather than through a card processor. If something goes wrong, use \"Report a problem\" and the Hiww team will step in before any money moves.'**
  String get howProtectionPilotNote;

  /// No description provided for @emptyInboxTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get emptyInboxTitle;

  /// No description provided for @emptyInboxMessage.
  ///
  /// In en, this message translates to:
  /// **'Chats appear here once you have an order with a traveler or shopper.'**
  String get emptyInboxMessage;

  /// No description provided for @fallbackConversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get fallbackConversation;

  /// No description provided for @errorAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not attach that photo. Try another.'**
  String get errorAttachPhoto;

  /// No description provided for @chatFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatFallbackTitle;

  /// No description provided for @sayHello.
  ///
  /// In en, this message translates to:
  /// **'Say hello 👋'**
  String get sayHello;

  /// No description provided for @tooltipRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get tooltipRemovePhoto;

  /// No description provided for @tooltipAttachPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attach a photo'**
  String get tooltipAttachPhoto;

  /// No description provided for @uploadingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Uploading photo…'**
  String get uploadingPhoto;

  /// No description provided for @photoAttachedTapSend.
  ///
  /// In en, this message translates to:
  /// **'Photo attached. Tap send to share it.'**
  String get photoAttachedTapSend;

  /// No description provided for @hintMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get hintMessage;

  /// No description provided for @tooltipSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get tooltipSend;

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @statusRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get statusRead;

  /// No description provided for @purchaseReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase receipt'**
  String get purchaseReceiptTitle;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get actionGetStarted;

  /// No description provided for @onboardingSlide1Title.
  ///
  /// In en, this message translates to:
  /// **'Shop from anywhere'**
  String get onboardingSlide1Title;

  /// No description provided for @onboardingSlide1Body.
  ///
  /// In en, this message translates to:
  /// **'Get almost anything from abroad — travelers pick it up and bring it to you.'**
  String get onboardingSlide1Body;

  /// No description provided for @onboardingSlide2Title.
  ///
  /// In en, this message translates to:
  /// **'Delivered by real travelers'**
  String get onboardingSlide2Title;

  /// No description provided for @onboardingSlide2Body.
  ///
  /// In en, this message translates to:
  /// **'No warehouses — just real travelers already heading your way.'**
  String get onboardingSlide2Body;

  /// No description provided for @onboardingSlide3Title.
  ///
  /// In en, this message translates to:
  /// **'Earn on trips you already take'**
  String get onboardingSlide3Title;

  /// No description provided for @onboardingSlide3Body.
  ///
  /// In en, this message translates to:
  /// **'Carry a few extra items on your next trip and get paid for it.'**
  String get onboardingSlide3Body;

  /// No description provided for @landingTagline.
  ///
  /// In en, this message translates to:
  /// **'Shop the world, delivered by travelers.'**
  String get landingTagline;

  /// No description provided for @actionSignInLine.
  ///
  /// In en, this message translates to:
  /// **'Sign in with LINE'**
  String get actionSignInLine;

  /// No description provided for @actionContinueFacebook.
  ///
  /// In en, this message translates to:
  /// **'Continue with Facebook'**
  String get actionContinueFacebook;

  /// No description provided for @actionSignInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get actionSignInGoogle;

  /// No description provided for @dividerOrUseEmail.
  ///
  /// In en, this message translates to:
  /// **'or use your email'**
  String get dividerOrUseEmail;

  /// No description provided for @actionExploreGuest.
  ///
  /// In en, this message translates to:
  /// **'Explore Hiww — create an account later'**
  String get actionExploreGuest;

  /// No description provided for @providerLine.
  ///
  /// In en, this message translates to:
  /// **'LINE'**
  String get providerLine;

  /// No description provided for @providerFacebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get providerFacebook;

  /// No description provided for @providerGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get providerGoogle;

  /// No description provided for @errorSocialNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'{provider} sign-in isn\'t set up yet'**
  String errorSocialNotConfigured(String provider);

  /// No description provided for @errorSocialSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn\'t go through. Please try again.'**
  String get errorSocialSignInFailed;

  /// No description provided for @infoLogInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Log in to continue'**
  String get infoLogInToContinue;

  /// No description provided for @landingTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By using Hiww, I agree to Hiww\'s'**
  String get landingTermsPrefix;

  /// No description provided for @actionTermsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get actionTermsOfUse;

  /// No description provided for @landingTermsAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get landingTermsAnd;

  /// No description provided for @actionPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get actionPrivacyPolicy;
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
