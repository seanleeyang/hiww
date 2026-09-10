// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tabBrowse => 'Home';

  @override
  String get tabMyTrips => 'Trips';

  @override
  String get tabMyWants => 'My Wants';

  @override
  String get tabOffers => 'Offers';

  @override
  String get tabOrders => 'Orders';

  @override
  String get tabInbox => 'Inbox';

  @override
  String ordersTabRequested(int count) {
    return '$count Requested';
  }

  @override
  String ordersTabInTransit(int count) {
    return '$count In Transit';
  }

  @override
  String ordersTabReceived(int count) {
    return '$count Received';
  }

  @override
  String ordersTabInactive(int count) {
    return '$count Inactive';
  }

  @override
  String get emptyOrdersBucketTitle => 'Nothing here yet';

  @override
  String get emptyOrdersBucketMessage =>
      'Orders at this stage will show up here.';

  @override
  String get tripsTabActive => 'Active';

  @override
  String get tripsTabPast => 'Past';

  @override
  String get emptyTripsPastTitle => 'No past trips';

  @override
  String get emptyTripsPastMessage =>
      'Trips that have ended or been cancelled show up here.';

  @override
  String get inboxTabMessages => 'Messages';

  @override
  String get inboxTabNotifications => 'Notifications';

  @override
  String get notificationsEmptyTitle => 'Nothing yet';

  @override
  String get notificationsEmptyMessage =>
      'Updates on your orders — payments, shipping, delivery — show up here.';

  @override
  String get actionMarkAllRead => 'Mark all read';

  @override
  String get tooltipSettings => 'Settings';

  @override
  String get tooltipAccount => 'Account';

  @override
  String get settingsTitle => 'Settings';

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
  String get actionCreateAccount => 'Sign up';

  @override
  String get actionForgotPassword => 'Forgot password?';

  @override
  String get actionStaySignedIn => 'Stay signed in';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email and we\'ll send you a reset code.';

  @override
  String get actionSendCode => 'Send code';

  @override
  String get errorForgotPasswordFailed =>
      'Could not send a reset code. Please try again.';

  @override
  String get resetPasswordTitle => 'Enter your reset code';

  @override
  String resetPasswordSubtitle(String email) {
    return 'We\'ve sent a 6-digit code to $email.';
  }

  @override
  String get fieldNewPassword => 'New password';

  @override
  String get actionResetPassword => 'Reset password';

  @override
  String get errorResetPasswordFailed =>
      'Could not reset your password. Please try again.';

  @override
  String get rememberedPassword => 'Remembered your password?';

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
  String get actionCreateAccountButton => 'Sign up';

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
  String get browseTabOrder => 'Order';

  @override
  String get browseTabTravel => 'Travel';

  @override
  String get actionPostATrip => 'Add Trip';

  @override
  String get actionPostAWant => 'Create Order';

  @override
  String get proTipTitle => 'Pro tip';

  @override
  String get proTipCreateOrderBody =>
      'Be sure to provide all product specifics about your order to be sure you receive the correct item.';

  @override
  String heroOrderGreetingNamed(String name) {
    return 'Hi $name, what would you like to order?';
  }

  @override
  String get heroOrderGreetingGuest =>
      'Hi there, what would you like to order?';

  @override
  String get heroOrderTagline =>
      'Find travelers heading your way and get almost anything delivered.';

  @override
  String get heroOrderCta => 'I\'m ready to start my order';

  @override
  String heroTravelGreetingNamed(String name) {
    return 'Hi $name, ready to earn on your next trip?';
  }

  @override
  String get heroTravelGreetingGuest =>
      'Hi there, ready to earn on your next trip?';

  @override
  String get heroTravelTagline =>
      'Carry a few extra items for shoppers on your route and get paid for it.';

  @override
  String get heroTravelCta => 'Post your trip';

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

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionContinue => 'Continue';

  @override
  String get verifyGateTitle => 'Before You Proceed';

  @override
  String get verifyGateBody =>
      'Our mission is to build a safe community of shoppers and travelers who help each other shop across borders. To keep everyone protected, we\'ll need to confirm a few quick details before you continue.';

  @override
  String get dialogRemoveFromListBody =>
      'It disappears from your list. This does not affect its history.';

  @override
  String get tooltipRemoveFromList => 'Remove from your list';

  @override
  String get dialogRemoveTripTitle => 'Remove this trip?';

  @override
  String get emptyMyTripsTitle => 'No trips yet';

  @override
  String get emptyMyTripsMessage =>
      'Post a trip and shoppers can request items along your route.';

  @override
  String get errorPickTravelDates => 'Pick your travel dates';

  @override
  String get errorEnterWeightAndItems => 'Enter spare weight and item count';

  @override
  String get errorReturnAfterDeparture => 'Return date must be after departure';

  @override
  String get dialogCancelTripTitle => 'Cancel this trip?';

  @override
  String get dialogCancelTripBody =>
      'Shoppers will no longer be able to find or offer against this trip. This can\'t be undone.';

  @override
  String get actionKeepTrip => 'Keep trip';

  @override
  String get actionCancelTrip => 'Cancel trip';

  @override
  String get errorTripHasActiveOrder =>
      'This trip has an order still in progress. Use \"Report a problem\" on that order instead — cancelling the trip itself won\'t resolve it.';

  @override
  String get tripEditTitle => 'Edit trip';

  @override
  String get labelFrom => 'From';

  @override
  String get labelTo => 'To';

  @override
  String get labelDeparture => 'Departure';

  @override
  String get labelReturn => 'Return';

  @override
  String get fieldSpareWeightKg => 'Spare weight (kg)';

  @override
  String get fieldMaxItems => 'Max items';

  @override
  String get fieldNoteOptional => 'Note (optional)';

  @override
  String get hintNoteTrip => 'What you can carry, preferences…';

  @override
  String get fieldCoverPhotoOptional => 'Add a cover photo (optional)';

  @override
  String get actionSaveChanges => 'Save changes';

  @override
  String get actionPostTrip => 'Add Trip';

  @override
  String get fieldCityOptional => 'City (optional)';

  @override
  String get heroTravelFormHeading =>
      'Add your trip details to start earning money';

  @override
  String get labelTravelingFrom => 'Traveling from';

  @override
  String get labelTravelingTo => 'Traveling to';

  @override
  String get labelTravelDates => 'Travel dates';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionDone => 'Done';

  @override
  String get locationSearchTitle => 'Search';

  @override
  String get locationRecentSection => 'Recent locations';

  @override
  String get tripDetailTitle => 'Trip';

  @override
  String tripSpareCapacity(String weightKg, int maxItems) {
    return '$weightKg kg spare · up to $maxItems items';
  }

  @override
  String get actionRequestFromThisTrip => 'Request from this trip';

  @override
  String get tripDetailOwnerNote =>
      'This is your trip. Shoppers can request items along this route.';

  @override
  String get dialogRemoveWantTitle => 'Remove this want?';

  @override
  String get emptyMyWantsTitle => 'No wants yet';

  @override
  String get emptyMyWantsMessage =>
      'Post what you want bought abroad and travelers will make offers.';

  @override
  String wantBudgetLine(String budget) {
    return 'Budget $budget';
  }

  @override
  String wantBuyInLine(String place) {
    return 'Buy in $place';
  }

  @override
  String wantDeliverToLine(String place) {
    return 'Deliver to $place';
  }

  @override
  String wantProductUrlLine(String url) {
    return 'Product URL: $url';
  }

  @override
  String get actionViewOrder => 'View order →';

  @override
  String get errorWantTitleBlank => 'Product Name cannot be left blank';

  @override
  String get errorWantTitleTooShort =>
      'Product Name must be longer than 3 characters';

  @override
  String get errorWantDetailsBlank => 'Product Details cannot be left blank';

  @override
  String get errorWantDetailsTooShort =>
      'Product Details must be longer than 10 characters';

  @override
  String get wantEditTitle => 'Edit want';

  @override
  String directRequestNotice(String name) {
    return 'Sent directly to $name — not shown publicly. Your budget below is your opening price; they can accept, counter, or decline.';
  }

  @override
  String get fieldProductUrlOptional => 'Product URL (optional)';

  @override
  String get hintProductUrl => 'Paste a link to the exact item';

  @override
  String get fieldItem => 'Product Name';

  @override
  String get hintItemExample => 'e.g. Nike Dunk Panda';

  @override
  String get fieldDetails => 'Product Details';

  @override
  String get hintDetails => 'Brand, model, size, colour, links';

  @override
  String get tooltipProductDetails =>
      'Provide as much information about the product as you can, so that the traveler buys the correct item.';

  @override
  String get fieldPhotoOptional => 'Add a photo (optional)';

  @override
  String get fieldPhoto => 'Add a photo';

  @override
  String get errorPhotoRequired => 'Add a photo of the item';

  @override
  String get labelCategory => 'Category';

  @override
  String get labelBudget => 'Budget';

  @override
  String budgetTotalNote(num qty) {
    String _temp0 = intl.Intl.pluralLogic(
      qty,
      locale: localeName,
      other: '$qty items',
      one: '$qty item',
    );
    return 'Total you expect to pay, for all $_temp0.';
  }

  @override
  String get labelQuantity => 'Quantity';

  @override
  String get labelNeedBy => 'Need by';

  @override
  String get tooltipNeedBy =>
      'The longer period you are ready to wait, the more offers you receive and can choose from.';

  @override
  String get anyTime => 'Any time';

  @override
  String get labelBuyIn => 'Buy in';

  @override
  String get labelDeliverTo => 'Deliver to';

  @override
  String get labelCountry => 'Country';

  @override
  String get selectOption => 'Select';

  @override
  String get cityOptionAny => 'Any';

  @override
  String get cityOptionOthers => 'Others';

  @override
  String get hintCityCustom => 'Enter your city';

  @override
  String get errorBuyInCountryRequired =>
      'Buy in (Country) cannot be left blank';

  @override
  String get errorBuyInCityRequired => 'Buy in (City) cannot be left blank';

  @override
  String get errorDeliverToCountryRequired =>
      'Deliver to (Country) cannot be left blank';

  @override
  String get errorDeliverToCityRequired =>
      'Deliver to (City) cannot be left blank';

  @override
  String get hintCityExample => 'Tokyo';

  @override
  String travelersHeadingSoon(num count, String country) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count travelers',
      one: '$count traveler',
    );
    return '$_temp0 heading to $country soon';
  }

  @override
  String get actionNext => 'Next';

  @override
  String get summaryScreenTitle => 'Summary';

  @override
  String get actionSendRequest => 'Send request';

  @override
  String get actionPostMyWant => 'Submit';

  @override
  String get wantDetailTitle => 'Want';

  @override
  String get directRequestBadge =>
      'Sent directly to one traveler — not shown publicly';

  @override
  String wantQuantityLine(int qty) {
    return 'Quantity $qty';
  }

  @override
  String get actionMakeAnOffer => 'Make an offer';

  @override
  String get wantClosedNote => 'This want is no longer taking offers.';

  @override
  String get dialogCancelWantTitle => 'Cancel this want?';

  @override
  String get dialogCancelWantBody =>
      'Travelers will no longer see it or be able to offer on it. This can\'t be undone.';

  @override
  String get actionKeepWant => 'Keep want';

  @override
  String get actionCancelWant => 'Cancel want';

  @override
  String get noOffersYetMessage =>
      'No offers yet — travelers on this route will see it.';

  @override
  String get labelYourOffer => 'Your offer';

  @override
  String get dialogAcceptOfferTitle => 'Accept this offer?';

  @override
  String dialogAcceptOfferBody(String price) {
    return 'You will pay $price for the item. An order is created and you\'ll be asked to pay.';
  }

  @override
  String get priceBreakdownProductPrice => 'Product Price';

  @override
  String get priceBreakdownTravellerReward => 'Traveller Reward';

  @override
  String get priceBreakdownServiceFee => 'Service & Protection Fee';

  @override
  String get priceBreakdownTotal => 'Total';

  @override
  String get travellerBreakdownProductValue => 'Product Value';

  @override
  String get travellerBreakdownYourReward => 'Your Reward';

  @override
  String get travellerBreakdownYouReceive => 'You Receive';

  @override
  String get actionAccept => 'Accept';

  @override
  String offerCounteredTimes(num round) {
    String _temp0 = intl.Intl.pluralLogic(
      round,
      locale: localeName,
      other: '$round times',
      one: '$round time',
    );
    return 'Countered $_temp0';
  }

  @override
  String get fallbackTraveler => 'Traveler';

  @override
  String get errorPickTripForOffer => 'Pick which trip this is for';

  @override
  String get errorEnterYourPrice => 'Enter your price';

  @override
  String get errorPickDeliveryDate => 'Pick a delivery date';

  @override
  String get errorDeliveryBeforeReturn =>
      'Delivery date must be on or after the trip\'s return date';

  @override
  String get infoOfferSent => 'Offer sent';

  @override
  String get makeOfferTitle => 'Make an offer';

  @override
  String get emptyNeedTripTitle => 'You need a trip first';

  @override
  String get emptyNeedTripMessage =>
      'Post a trip you can carry this item on, then make your offer.';

  @override
  String get labelWhichTrip => 'Which trip';

  @override
  String get fieldYourPriceForGoods => 'Your price for the item';

  @override
  String get labelDeliverBy => 'Deliver by';

  @override
  String hintDeliverByFromReturn(String date) {
    return 'Must be on or after the trip\'s return date, $date';
  }

  @override
  String get actionPickADate => 'Pick a date';

  @override
  String get actionSendOffer => 'Send offer';

  @override
  String get emptyOffersTitle => 'No offers yet';

  @override
  String get emptyOffersMessage =>
      'Offers you make or receive — as a shopper or a traveler — show up here.';

  @override
  String offerFromLabel(String name) {
    return 'Offer from $name';
  }

  @override
  String offerToLabel(String name) {
    return 'To $name';
  }

  @override
  String get fallbackATraveler => 'a traveler';

  @override
  String get fallbackAShopper => 'a shopper';

  @override
  String get fallbackOfferTitle => 'Offer';

  @override
  String get dialogCounterOfferTitle => 'Counter Offer';

  @override
  String get fieldYourPrice => 'Your price';

  @override
  String get actionSubmit => 'Submit';

  @override
  String get waitingForResponse => 'Waiting for a response';

  @override
  String waitingForResponseWithCountdown(String countdown) {
    return 'Waiting for a response · $countdown';
  }

  @override
  String get wantNoLongerOpen => 'This want is no longer open';

  @override
  String respondWithin(String countdown) {
    return 'Respond within $countdown';
  }

  @override
  String actionAcceptPrice(String price) {
    return 'Accept $price';
  }

  @override
  String get actionCounter => 'Counter Offer';

  @override
  String get actionDecline => 'Decline';

  @override
  String get actionDeclineFinalOffer => 'Decline (final offer)';

  @override
  String offerHistoryOffered(String price) {
    return 'Offered $price';
  }

  @override
  String offerHistoryCountered(String price) {
    return 'Countered at $price';
  }

  @override
  String get emptyOrdersTitle => 'No orders yet';

  @override
  String get emptyOrdersMessage =>
      'When you accept an offer or one of your offers is accepted, the order shows up here so you can track every step.';

  @override
  String orderRelationBuying(String name) {
    return 'Buying from $name';
  }

  @override
  String orderRelationDelivering(String name) {
    return 'Delivering for $name';
  }

  @override
  String get nextStepWaitingForOffers => 'Waiting for offers';

  @override
  String get nextStepOfferNeedsResponse => 'An offer needs your response';

  @override
  String get nextStepWaitingOnOtherSide => 'Waiting for their response';

  @override
  String get nextStepPayToStart => 'Pay to get things moving';

  @override
  String get nextStepWaitingForPayment => 'Waiting for the shopper to pay';

  @override
  String get nextStepTravelerBuying => 'Traveler is buying your item';

  @override
  String get nextStepBuyThenUpload => 'Buy the item, then upload the receipt';

  @override
  String get nextStepBoughtWaitShip =>
      'Items purchased — traveler will ship once they’re back';

  @override
  String get nextStepPostThenShip => 'Post the item, then mark it shipped';

  @override
  String get nextStepOnWayConfirm => 'On its way — confirm when it arrives';

  @override
  String get nextStepShippedWaiting =>
      'Shipped — waiting for the shopper to confirm receipt';

  @override
  String orderHashTitle(String code) {
    return 'Order #$code';
  }

  @override
  String get roleCarrier => 'Carrier';

  @override
  String get roleShopper => 'Shopper';

  @override
  String get actionOpenChat => 'Open chat';

  @override
  String get actionReport => 'Report';

  @override
  String orderTotalWithFee(String total, String fee) {
    return '$total · $fee fee';
  }

  @override
  String get noteWaitingForShopperToPay => 'Waiting for the shopper to pay.';

  @override
  String payWithinOrCancel(String countdown) {
    return 'Pay within $countdown or the order is cancelled automatically.';
  }

  @override
  String shopperHasTimeToPay(String countdown) {
    return 'Shopper has $countdown to pay before the order auto-cancels.';
  }

  @override
  String get howToPayTitle => 'How to pay';

  @override
  String get contactHiwwForPayment =>
      'Contact the Hiww team to arrange payment.';

  @override
  String amountReference(String total, String id) {
    return 'Amount $total  ·  reference $id';
  }

  @override
  String get noteToldUsPaid =>
      'You\'ve told us you paid. We\'ll confirm once it lands.';

  @override
  String get actionSentPayment => 'I\'ve sent the payment';

  @override
  String get promptPayQrTitle => 'PromptPay QR code';

  @override
  String get promptPayQrComingSoon =>
      'Scan-to-pay is coming soon. For now, follow the instructions above.';

  @override
  String get notePaymentConfirmedWaitingBuy =>
      'Payment confirmed. Waiting for the traveler to buy the item.';

  @override
  String get notePaymentConfirmedUploadReceipt =>
      'Payment confirmed. Buy the item, then upload a photo of the item itself and a photo of the shop receipt — clear date and totals in frame. That unlocks the shipping step.';

  @override
  String get actionUploading => 'Uploading…';

  @override
  String get actionUploadReceipt => 'Upload purchase receipt';

  @override
  String get actionUploadItemPhoto => 'Upload item photo';

  @override
  String get actionSubmitPurchaseProof => 'Submit';

  @override
  String get actionUploadShippingProof => 'Add shipping proof (optional)';

  @override
  String get labelItemPhoto => 'Item photo';

  @override
  String get labelReceipt => 'Receipt';

  @override
  String get labelShippingProof => 'Shipping proof';

  @override
  String noteUploadDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other:
          'You have $days days left to upload the item photo and receipt before your trip ends.',
      one:
          'You have $days day left to upload the item photo and receipt before your trip ends.',
      zero: 'No days left to upload the item photo and receipt before your trip ends.',
    );
    return '$_temp0';
  }

  @override
  String get noteTravelerBoughtWillShip =>
      'The traveler bought your item. They’ll ship it once they’re back in the origin country.';

  @override
  String get noteReceiptUploadedPostShip =>
      'Receipt uploaded. Post the item when you’re home, then mark it shipped.';

  @override
  String get actionMarkShipped => 'Mark as shipped';

  @override
  String get noteShippedWaitingConfirm =>
      'Shipped. Waiting for the shopper to confirm receipt.';

  @override
  String get noteOnWayConfirm =>
      'On the way. Confirm once you have it in hand.';

  @override
  String actionConfirmRelease(String total) {
    return 'Confirm & release $total';
  }

  @override
  String get ratedLabel => 'You rated';

  @override
  String actionRateCounterparty(String name) {
    return 'Rate $name';
  }

  @override
  String get fallbackTheOtherParty => 'the other party';

  @override
  String get noteCompletedThanks => 'Completed. Thanks for using Hiww!';

  @override
  String orderStatusFallback(String status) {
    return 'This order is $status.';
  }

  @override
  String get stageAcceptedTitle => 'Accepted';

  @override
  String get stageAcceptedHint => 'Offer accepted';

  @override
  String get stagePaidTitle => 'Paid';

  @override
  String get stagePaidHint => 'Payment confirmed';

  @override
  String get stageBoughtTitle => 'Items purchased';

  @override
  String get stageBoughtHint => 'Traveler bought the item';

  @override
  String get stageInTransitTitle => 'In transit';

  @override
  String get stageInTransitHint => 'On the way to you';

  @override
  String get stageDeliveredTitle => 'Delivered';

  @override
  String get stageDeliveredHint => 'Confirm to release payment';

  @override
  String get errorTapStarToRate => 'Tap a star to rate';

  @override
  String get infoThanksForReview => 'Thanks for the review';

  @override
  String get infoPaymentReleased => 'Payment released — thank you!';

  @override
  String get leaveReviewTitle => 'Leave a review';

  @override
  String get confirmAndReviewTitle => 'Confirm & review';

  @override
  String get fallbackTheTraveler => 'the traveler';

  @override
  String howWasName(String name) {
    return 'How was $name?';
  }

  @override
  String get hintShareHandover => 'Share how the handover went (optional)';

  @override
  String get actionSubmitReview => 'Submit review';

  @override
  String releaseNoteToName(String name) {
    return 'This releases the held payment to $name.';
  }

  @override
  String get errorDescribeProblem =>
      'Please describe the problem (at least 10 characters)';

  @override
  String get infoReported => 'Reported — the Hiww team will look into it';

  @override
  String get reportProblemTitle => 'Report a problem';

  @override
  String get reportProblemSubtitle =>
      'Money stays held while the Hiww team reviews this.';

  @override
  String get hintWhatWentWrong => 'What went wrong?';

  @override
  String get actionSubmitReport => 'Submit report';

  @override
  String trustReleasedTo(String total) {
    return 'Released — $total to the traveler';
  }

  @override
  String trustHolding(String total, String fee) {
    return 'Hiww is holding $total + $fee fee';
  }

  @override
  String trustHoldingTotal(String total) {
    return 'Hiww is holding $total';
  }

  @override
  String get trustSettled => 'Payment for this item has been settled.';

  @override
  String get trustReleasedOnConfirm =>
      'Released to the traveler when you confirm you have the item.';

  @override
  String get trustReleasedOnConfirmTraveler =>
      'Released to you once the shopper receives and confirms the item.';

  @override
  String get actionHowProtectionWorks => 'How payment protection works';

  @override
  String get howProtectionStep1 => 'You pay Hiww when you accept an offer.';

  @override
  String get howProtectionStep2 =>
      'Hiww holds the money — the traveler is not paid yet.';

  @override
  String get howProtectionStep3 => 'The traveler buys and ships your item.';

  @override
  String get howProtectionStep4 =>
      'You confirm you received it, and Hiww releases the payment.';

  @override
  String get howProtectionPilotNote =>
      'During the pilot, Hiww settles payments by hand rather than through a card processor. If something goes wrong, use \"Report a problem\" and the Hiww team will step in before any money moves.';

  @override
  String get emptyInboxTitle => 'No messages yet';

  @override
  String get emptyInboxMessage =>
      'Chats appear here once you have an order with a traveler or shopper.';

  @override
  String get fallbackConversation => 'Conversation';

  @override
  String get errorAttachPhoto => 'Could not attach that photo. Try another.';

  @override
  String get chatFallbackTitle => 'Chat';

  @override
  String get sayHello => 'Say hello 👋';

  @override
  String get tooltipRemovePhoto => 'Remove photo';

  @override
  String get tooltipAttachPhoto => 'Attach a photo';

  @override
  String get uploadingPhoto => 'Uploading photo…';

  @override
  String get photoAttachedTapSend => 'Photo attached. Tap send to share it.';

  @override
  String get hintMessage => 'Message';

  @override
  String get tooltipSend => 'Send';

  @override
  String get statusSent => 'Sent';

  @override
  String get statusRead => 'Read';

  @override
  String get purchaseReceiptTitle => 'Purchase receipt';

  @override
  String get shippingProofTitle => 'Shipping proof';

  @override
  String get chatClosedBanner => 'This chat is closed — the order is complete.';

  @override
  String get chatDeletedMessage => 'You deleted this conversation.';

  @override
  String get actionDeleteChat => 'Delete chat';

  @override
  String get dialogDeleteChatTitle => 'Delete this chat?';

  @override
  String get dialogDeleteChatBody =>
      'This only removes it from your own inbox. The other person can still see it.';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionGetStarted => 'Get started';

  @override
  String get onboardingSlide1Title => 'Shop from anywhere';

  @override
  String get onboardingSlide1Body =>
      'Get almost anything from abroad — travelers pick it up and bring it to you.';

  @override
  String get onboardingSlide2Title => 'Delivered by real travelers';

  @override
  String get onboardingSlide2Body =>
      'No warehouses — just real travelers already heading your way.';

  @override
  String get onboardingSlide3Title => 'Earn on trips you already take';

  @override
  String get onboardingSlide3Body =>
      'Carry a few extra items on your next trip and get paid for it.';

  @override
  String get landingTagline => 'Shop the world, delivered by travelers.';

  @override
  String get actionSignInLine => 'Sign in with LINE';

  @override
  String get actionContinueFacebook => 'Continue with Facebook';

  @override
  String get actionSignInGoogle => 'Sign in with Google';

  @override
  String get dividerOrUseEmail => 'or use your email';

  @override
  String get actionExploreGuest => 'Explore Hiww — create an account later';

  @override
  String get providerLine => 'LINE';

  @override
  String get providerFacebook => 'Facebook';

  @override
  String get providerGoogle => 'Google';

  @override
  String errorSocialNotConfigured(String provider) {
    return '$provider sign-in isn\'t set up yet';
  }

  @override
  String get errorSocialSignInFailed =>
      'Sign-in didn\'t go through. Please try again.';

  @override
  String get infoLogInToContinue => 'Log in to continue';

  @override
  String get landingTermsPrefix => 'By using Hiww, I agree to Hiww\'s';

  @override
  String get actionTermsOfUse => 'Terms of Use';

  @override
  String get landingTermsAnd => 'and';

  @override
  String get actionPrivacyPolicy => 'Privacy Policy';
}
