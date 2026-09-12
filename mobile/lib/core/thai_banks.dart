/// Thai commercial + state-owned banks offered in the Bank Account picker.
/// `value` is stored as-is in `users.bank_name` (unchanged from before this
/// list gained Thai labels, so existing stored values still match) — this is
/// the whole set of currently-operating banks a user could plausibly hold a
/// payout account with, so there's no separate code to keep in sync with a
/// bank list elsewhere. `nameTh` is shown instead of `value` when the app's
/// locale is Thai (see `bankLabel`); the stored value itself never changes
/// with locale, same reasoning as `kCategoryValues`.
const kThaiBanks = <({String value, String nameTh})>[
  (value: 'Bangkok Bank', nameTh: 'ธนาคารกรุงเทพ'),
  (value: 'Kasikornbank (KBank)', nameTh: 'ธนาคารกสิกรไทย'),
  (value: 'Krungthai Bank', nameTh: 'ธนาคารกรุงไทย'),
  (value: 'Siam Commercial Bank (SCB)', nameTh: 'ธนาคารไทยพาณิชย์'),
  (value: 'Bank of Ayudhya (Krungsri)', nameTh: 'ธนาคารกรุงศรีอยุธยา'),
  (value: 'TMBThanachart Bank (ttb)', nameTh: 'ธนาคารทีทีบี'),
  (value: 'Kiatnakin Phatra Bank', nameTh: 'ธนาคารเกียรตินาคินภัทร'),
  (value: 'CIMB Thai Bank', nameTh: 'ธนาคารซีไอเอ็มบีไทย'),
  (value: 'United Overseas Bank (Thai)', nameTh: 'ธนาคารยูโอบี'),
  (value: 'Standard Chartered (Thai)', nameTh: 'ธนาคารสแตนดาร์ดชาร์เตอร์ด (ไทย)'),
  (value: 'Land and Houses Bank', nameTh: 'ธนาคารแลนด์ แอนด์ เฮ้าส์'),
  (value: 'Thai Credit Bank', nameTh: 'ธนาคารไทยเครดิต'),
  (value: 'ICBC (Thai)', nameTh: 'ธนาคารไอซีบีซี (ไทย)'),
  (value: 'Government Savings Bank', nameTh: 'ธนาคารออมสิน'),
  (value: 'Government Housing Bank', nameTh: 'ธนาคารอาคารสงเคราะห์'),
  (value: 'Bank for Agriculture and Agricultural Cooperatives (BAAC)', nameTh: 'ธนาคารเพื่อการเกษตรและสหกรณ์การเกษตร (ธ.ก.ส.)'),
  (value: 'Islamic Bank of Thailand', nameTh: 'ธนาคารอิสลามแห่งประเทศไทย'),
  (value: 'Export-Import Bank of Thailand (EXIM)', nameTh: 'ธนาคารเพื่อการส่งออกและนำเข้าแห่งประเทศไทย'),
  (value: 'SME Development Bank of Thailand', nameTh: 'ธนาคารพัฒนาวิสาหกิจขนาดกลางและขนาดย่อมแห่งประเทศไทย'),
];

/// [locale] is an [AppLocalizations.localeName] ('en' | 'th'). Falls back to
/// [value] itself for anything not in [kThaiBanks] (e.g. a stale value from
/// before this list changed).
String bankLabel(String? value, String locale) {
  if (value == null || value.isEmpty) return '';
  if (locale != 'th') return value;
  for (final b in kThaiBanks) {
    if (b.value == value) return b.nameTh;
  }
  return value;
}
