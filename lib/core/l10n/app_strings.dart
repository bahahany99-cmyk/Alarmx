// Tiny Arabic-first localization tables for AlarmX (Phase 3).
//
// This is deliberately the smallest clean architecture that satisfies the
// roadmap's "Arabic + English, RTL from the beginning" requirement: two
// static string tables (Arabic first, English second) resolved from the
// ambient [Localizations] locale, which the app shell drives from the
// stored `AppSettings.language` field ('ar' by schema default).
//
// What lives here: every user-visible string owned by AlarmX UI.
// What does NOT live here: Material/Cupertino widget strings (time/date
// picker buttons, dialog labels, ...), which come from the Flutter SDK's
// `flutter_localizations` delegates wired in `main.dart`, and date/time
// *formatting*, which uses `MaterialLocalizations` so digits, calendars
// and day/month names follow the active locale automatically.
//
// Conventions:
//   - `AppStrings.of(context)` never throws: unknown locales fall back to
//     Arabic, unknown keys fall back to the English table, then to the key.
//   - The two tables must hold exactly the same keys (enforced by test).

import 'package:flutter/widgets.dart';

/// Supported UI languages. Arabic is first: it is the schema default of
/// `AppSettings.language` and the roadmap's primary language.
class AppLanguage {
  /// Arabic (`ar`).
  static const String arabic = 'ar';

  /// English (`en`).
  static const String english = 'en';

  /// Language codes the UI can render, primary first.
  static const List<String> supported = <String>[arabic, english];

  /// Used when the stored or requested code is not supported.
  static const String fallback = arabic;

  /// Returns [code] when supported, otherwise [fallback]. Never throws.
  static String normalize(String? code) {
    return supported.contains(code) ? code! : fallback;
  }
}

/// Localized AlarmX strings for the ambient locale.
class AppStrings {
  const AppStrings._(this._table);

  final Map<String, String> _table;

  /// Strings for the ambient locale (`Localizations.localeOf(context)`).
  static AppStrings of(BuildContext context) {
    return AppStrings.forCode(Localizations.localeOf(context).languageCode);
  }

  /// Strings for an explicit language code (also used by tests).
  factory AppStrings.forCode(String? code) {
    return AppStrings._(
      AppLanguage.normalize(code) == AppLanguage.english ? _en : _ar,
    );
  }

  /// Raw lookup with English-then-key fallback. Exposed so tests can assert
  /// table parity; UI code should use the typed getters below.
  String text(String key) => _table[key] ?? _en[key] ?? key;

  /// Every key the tables must define. Exposed for the parity test.
  static Set<String> get keys => _en.keys.toSet();

  String get appTitle => text('appTitle');
  String get homeTitle => text('homeTitle');
  String get homeEmptyTitle => text('homeEmptyTitle');
  String get homeEmptySubtitle => text('homeEmptySubtitle');
  String get addAlarm => text('addAlarm');
  String get createAlarmTitle => text('createAlarmTitle');
  String get editAlarmTitle => text('editAlarmTitle');
  String get onLabel => text('onLabel');
  String get offLabel => text('offLabel');
  String get nextLabel => text('nextLabel');
  String get notScheduled => text('notScheduled');
  String get labelLabel => text('labelLabel');
  String get labelHint => text('labelHint');
  String get timeLabel => text('timeLabel');
  String get changeTime => text('changeTime');
  String get dateLabel => text('dateLabel');
  String get changeDate => text('changeDate');
  String get repeatLabel => text('repeatLabel');
  String get repeatOnce => text('repeatOnce');
  String get repeatDaily => text('repeatDaily');
  String get repeatCustom => text('repeatCustom');
  String get soundLabel => text('soundLabel');
  String get soundDefault => text('soundDefault');
  String get soundCustom => text('soundCustom');
  String get soundUriLabel => text('soundUriLabel');
  String get soundUriHint => text('soundUriHint');
  String get soundFutureCaption => text('soundFutureCaption');
  String get volumeLabel => text('volumeLabel');
  String get vibrationLabel => text('vibrationLabel');
  String get fadeInLabel => text('fadeInLabel');
  String get fadeInCaption => text('fadeInCaption');
  String get snoozeLabel => text('snoozeLabel');
  String get snoozeDuration => text('snoozeDuration');
  String get snoozeMaxCount => text('snoozeMaxCount');
  String get snoozeCaption => text('snoozeCaption');
  String get missionTitle => text('missionTitle');
  String get missionNone => text('missionNone');
  String get missionCaption => text('missionCaption');
  String get save => text('save');
  String get cancel => text('cancel');
  String get delete => text('delete');
  String get deleteTitle => text('deleteTitle');
  String get deleteMessage => text('deleteMessage');
  String get languageMenu => text('languageMenu');
  String get langArabic => text('langArabic');
  String get langEnglish => text('langEnglish');
  String get daySun => text('daySun');
  String get dayMon => text('dayMon');
  String get dayTue => text('dayTue');
  String get dayWed => text('dayWed');
  String get dayThu => text('dayThu');
  String get dayFri => text('dayFri');
  String get daySat => text('daySat');
  String get listSeparator => text('listSeparator');
  String get msgAlarmSaved => text('msgAlarmSaved');
  String get msgAlarmUpdated => text('msgAlarmUpdated');
  String get msgAlarmDeleted => text('msgAlarmDeleted');
  String get msgAlarmEnabled => text('msgAlarmEnabled');
  String get msgAlarmDisabled => text('msgAlarmDisabled');
  String get msgAlarmMissing => text('msgAlarmMissing');
  String get msgLoadFailed => text('msgLoadFailed');
  String get msgCreateFailed => text('msgCreateFailed');
  String get msgUpdateFailed => text('msgUpdateFailed');
  String get msgDeleteFailed => text('msgDeleteFailed');
  String get msgToggleFailed => text('msgToggleFailed');
  String get msgNoPermission => text('msgNoPermission');
  String get msgNotSchedulable => text('msgNotSchedulable');
  String get msgScheduleFailed => text('msgScheduleFailed');
  String get msgValidationDays => text('msgValidationDays');
  String get missionAdd => text('missionAdd');
  String get missionEdit => text('missionEdit');
  String get missionDeleteTitle => text('missionDeleteTitle');
  String get missionDeleteMessage => text('missionDeleteMessage');
  String get missionRequired => text('missionRequired');
  String get missionOptional => text('missionOptional');
  String get missionSkip => text('missionSkip');
  String get missionMoveUp => text('missionMoveUp');
  String get missionMoveDown => text('missionMoveDown');
  String get missionPickType => text('missionPickType');
  String get missionTyping => text('missionTyping');
  String get missionPhoto => text('missionPhoto');
  String get missionQr => text('missionQr');
  String get missionBarcode => text('missionBarcode');
  String get missionShake => text('missionShake');
  String get missionMath => text('missionMath');
  String get missionProgress => text('missionProgress');
  String get missionCompleted => text('missionCompleted');
  String get missionCorrect => text('missionCorrect');
  String get missionIncorrect => text('missionIncorrect');
  String get missionRetry => text('missionRetry');
  String get missionCheck => text('missionCheck');
  String get missionSolve => text('missionSolve');
  String get missionDone => text('missionDone');
  String get typingInstruction => text('typingInstruction');
  String get typingHint => text('typingHint');
  String get typingExpectedLabel => text('typingExpectedLabel');
  String get photoInstruction => text('photoInstruction');
  String get photoTake => text('photoTake');
  String get photoLabel => text('photoLabel');
  String get photoCancelled => text('photoCancelled');
  String get photoError => text('photoError');
  String get qrInstruction => text('qrInstruction');
  String get qrValueLabel => text('qrValueLabel');
  String get barcodeInstruction => text('barcodeInstruction');
  String get barcodeValueLabel => text('barcodeValueLabel');
  String get scanCancel => text('scanCancel');
  String get scanWrongCode => text('scanWrongCode');
  String get scanError => text('scanError');
  String get shakeInstruction => text('shakeInstruction');
  String get shakeCountLabel => text('shakeCountLabel');
  String get mathInstruction => text('mathInstruction');
  String get mathAnswerHint => text('mathAnswerHint');
  String get mathCountLabel => text('mathCountLabel');
  String get mathDifficultyLabel => text('mathDifficultyLabel');
  String get mathEasy => text('mathEasy');
  String get mathMedium => text('mathMedium');
  String get mathHard => text('mathHard');
  String get permissionCameraTitle => text('permissionCameraTitle');
  String get permissionCameraMessage => text('permissionCameraMessage');
  String get permissionAllow => text('permissionAllow');
  String get permissionDenied => text('permissionDenied');
  String get permissionOpenSettings => text('permissionOpenSettings');
  String get permissionSensorMessage => text('permissionSensorMessage');
  String get sensorUnavailable => text('sensorUnavailable');
  String get ringingTitle => text('ringingTitle');
  String get ringingNoMissions => text('ringingNoMissions');
  String get ringingStop => text('ringingStop');
  String get ringingLoadFailed => text('ringingLoadFailed');
  String get ringingStopping => text('ringingStopping');
  String get ringingStopFailed => text('ringingStopFailed');
  String get ringingSkippedInvalid => text('ringingSkippedInvalid');
  String get msgMissionInvalid => text('msgMissionInvalid');
  String get msgMissionSaveFailed => text('msgMissionSaveFailed');
  String get msgSnoozeFailed => text('msgSnoozeFailed');
  String get securityTitle => text('securityTitle');
  String get pinEnable => text('pinEnable');
  String get pinDisable => text('pinDisable');
  String get pinChange => text('pinChange');
  String get pinStatusEnabled => text('pinStatusEnabled');
  String get pinStatusDisabled => text('pinStatusDisabled');
  String get pinCurrent => text('pinCurrent');
  String get pinNew => text('pinNew');
  String get pinConfirmNew => text('pinConfirmNew');
  String get pinEnter => text('pinEnter');
  String get pinUnlockTitle => text('pinUnlockTitle');
  String get pinConfirm => text('pinConfirm');
  String get msgPinMismatch => text('msgPinMismatch');
  String get msgPinInvalid => text('msgPinInvalid');
  String get msgPinIncorrect => text('msgPinIncorrect');
  String get strictDefaultLabel => text('strictDefaultLabel');
  String get strictDefaultCaption => text('strictDefaultCaption');
  String get strictModeLabel => text('strictModeLabel');
  String get strictModeCaption => text('strictModeCaption');
  String get msgStrictBlackout => text('msgStrictBlackout');
  String get missionLocked => text('missionLocked');
  String get missionUnlock => text('missionUnlock');
  String get ringingSnooze => text('ringingSnooze');
  String get ringingSnoozesLeft => text('ringingSnoozesLeft');
  String get ringingSnoozed => text('ringingSnoozed');
  String get ringingEmergencyDone => text('ringingEmergencyDone');
  String get ringingStrictLocked => text('ringingStrictLocked');
  String get emergencyTitle => text('emergencyTitle');
  String get emergencyHold => text('emergencyHold');
  String get emergencyUsePin => text('emergencyUsePin');
  String get emergencyCaption => text('emergencyCaption');
  String get historyTitle => text('historyTitle');
  String get historyEmptyTitle => text('historyEmptyTitle');
  String get historyEmptySubtitle => text('historyEmptySubtitle');
  String get historyStatusSuccess => text('historyStatusSuccess');
  String get historyStatusFailed => text('historyStatusFailed');
  String get historyStatusEmergency => text('historyStatusEmergency');
  String get historyStatusOngoing => text('historyStatusOngoing');
  String get historyStart => text('historyStart');
  String get historyStop => text('historyStop');
  String get historyResult => text('historyResult');
  String get historyAttempts => text('historyAttempts');
  String get historySnoozes => text('historySnoozes');
  String get historyUnknownAlarm => text('historyUnknownAlarm');
  String get statisticsTitle => text('statisticsTitle');
  String get statisticsCompleted => text('statisticsCompleted');
  String get statisticsFailed => text('statisticsFailed');
  String get statisticsAverage => text('statisticsAverage');
  String get statisticsFastest => text('statisticsFastest');
  String get statisticsHardest => text('statisticsHardest');
  String get statisticsUnavailable => text('statisticsUnavailable');
  String get msgMissionsLoadFailed => text('msgMissionsLoadFailed');
  String get missionFieldRequired => text('missionFieldRequired');

  static const Map<String, String> _ar = <String, String>{
    'appTitle': 'AlarmX',
    'homeTitle': 'المنبهات',
    'homeEmptyTitle': 'لا توجد منبهات بعد',
    'homeEmptySubtitle': 'أضف منبهك الأول وسيوقظك في موعده',
    'addAlarm': 'إضافة منبه',
    'createAlarmTitle': 'منبه جديد',
    'editAlarmTitle': 'تعديل المنبه',
    'onLabel': 'مفعّل',
    'offLabel': 'مغلق',
    'nextLabel': 'التالي',
    'notScheduled': 'غير مجدول',
    'labelLabel': 'الاسم',
    'labelHint': 'مثال: الاستيقاظ',
    'timeLabel': 'الوقت',
    'changeTime': 'تغيير الوقت',
    'dateLabel': 'التاريخ',
    'changeDate': 'تغيير التاريخ',
    'repeatLabel': 'التكرار',
    'repeatOnce': 'مرة واحدة',
    'repeatDaily': 'يومي',
    'repeatCustom': 'مخصص',
    'soundLabel': 'الصوت',
    'soundDefault': 'النغمة الافتراضية',
    'soundCustom': 'صوت مخصص',
    'soundUriLabel': 'رابط الصوت',
    'soundUriHint': 'مثال: content://...',
    'soundFutureCaption': 'يُحفظ الآن، ويعمل في تحديث الصوت القادم',
    'volumeLabel': 'مستوى الصوت',
    'vibrationLabel': 'الاهتزاز',
    'fadeInLabel': 'تصاعد الصوت تدريجيًا',
    'fadeInCaption': 'يُحفظ الآن، ويعمل في تحديث الصوت القادم',
    'snoozeLabel': 'الغفوة',
    'snoozeDuration': 'مدة الغفوة (بالدقائق)',
    'snoozeMaxCount': 'أقصى عدد للغفوات',
    'snoozeCaption': 'الإعدادات فقط في هذه النسخة؛ تنفيذ الغفوة في مرحلة قادمة',
    'missionTitle': 'مهمة الإيقاف',
    'missionNone': 'بدون مهمة',
    'missionCaption': 'حل المهام لإيقاف المنبه',
    'save': 'حفظ',
    'cancel': 'إلغاء',
    'delete': 'حذف',
    'deleteTitle': 'حذف المنبه؟',
    'deleteMessage': 'سيتم إلغاء جدولة هذا المنبه وحذفه نهائيًا.',
    'languageMenu': 'اللغة',
    'langArabic': 'العربية',
    'langEnglish': 'الإنجليزية',
    'daySun': 'الأحد',
    'dayMon': 'الاثنين',
    'dayTue': 'الثلاثاء',
    'dayWed': 'الأربعاء',
    'dayThu': 'الخميس',
    'dayFri': 'الجمعة',
    'daySat': 'السبت',
    'listSeparator': '، ',
    'msgAlarmSaved': 'تم حفظ المنبه وجدولته',
    'msgAlarmUpdated': 'تم تحديث المنبه',
    'msgAlarmDeleted': 'تم حذف المنبه',
    'msgAlarmEnabled': 'تم تفعيل المنبه',
    'msgAlarmDisabled': 'تم إغلاق المنبه',
    'msgAlarmMissing': 'المنبه غير موجود',
    'msgLoadFailed': 'تعذّر تحميل المنبه',
    'msgCreateFailed': 'تعذّر إنشاء المنبه',
    'msgUpdateFailed': 'تعذّر تحديث المنبه',
    'msgToggleFailed': 'تعذّر تغيير حالة المنبه',
    'msgDeleteFailed': 'تعذّر حذف المنبه',
    'msgNoPermission': 'تم الحفظ، لكن إذن المنبهات الدقيقة غير ممنوح',
    'msgNotSchedulable': 'تم الحفظ، لكن لا يوجد موعد قادم لهذا المنبه',
    'msgScheduleFailed': 'تم الحفظ، لكن تعذّرت الجدولة',
    'msgValidationDays': 'اختر يومًا واحدًا على الأقل للتكرار المخصص',
    'missionAdd': 'إضافة مهمة',
    'missionEdit': 'تعديل المهمة',
    'missionDeleteTitle': 'حذف المهمة؟',
    'missionDeleteMessage': 'إزالة هذه المهمة من المنبه؟',
    'missionRequired': 'مطلوبة',
    'missionOptional': 'اختيارية',
    'missionSkip': 'تخطي',
    'missionMoveUp': 'نقل لأعلى',
    'missionMoveDown': 'نقل لأسفل',
    'missionPickType': 'اختر نوع المهمة',
    'missionTyping': 'الكتابة',
    'missionPhoto': 'الصورة',
    'missionQr': 'QR',
    'missionBarcode': 'الباركود',
    'missionShake': 'الهز',
    'missionMath': 'الرياضيات',
    'missionProgress': 'المهمة',
    'missionCompleted': 'مكتملة',
    'missionCorrect': 'صحيح',
    'missionIncorrect': 'غير صحيح، حاول مجددًا',
    'missionRetry': 'حاول مجددًا',
    'missionCheck': 'تحقق',
    'missionSolve': 'حل',
    'missionDone': 'تم',
    'typingInstruction': 'اكتب النص التالي',
    'typingHint': 'اكتب هنا',
    'typingExpectedLabel': 'النص المطلوب كتابته',
    'photoInstruction': 'التقط صورة لإيقاف المنبه',
    'photoTake': 'التقط صورة',
    'photoLabel': 'ماذا تصوّر؟ (اختياري)',
    'photoCancelled': 'أُلغي التصوير — حاول مجددًا',
    'photoError': 'تعذّر استخدام الكاميرا — حاول مجددًا',
    'qrInstruction': 'امسح رمز QR',
    'qrValueLabel': 'قيمة رمز QR المتوقعة',
    'barcodeInstruction': 'امسح الباركود',
    'barcodeValueLabel': 'قيمة الباركود المتوقعة',
    'scanCancel': 'إلغاء المسح',
    'scanWrongCode': 'رمز غير صحيح — حاول مجددًا',
    'scanError': 'تعذّر المسح — حاول مجددًا',
    'shakeInstruction': 'هز هاتفك',
    'shakeCountLabel': 'عدد الهزات المطلوبة',
    'mathInstruction': 'حل لإيقاف المنبه',
    'mathAnswerHint': 'الإجابة',
    'mathCountLabel': 'عدد الأسئلة',
    'mathDifficultyLabel': 'الصعوبة',
    'mathEasy': 'سهلة',
    'mathMedium': 'متوسطة',
    'mathHard': 'صعبة',
    'permissionCameraTitle': 'يلزم إذن الكاميرا',
    'permissionCameraMessage': 'اسمح بالوصول إلى الكاميرا لإتمام هذه المهمة',
    'permissionAllow': 'سماح',
    'permissionDenied': 'تم رفض الإذن',
    'permissionOpenSettings': 'فتح الإعدادات',
    'permissionSensorMessage': 'يلزم حساس الحركة لإتمام هذه المهمة',
    'sensorUnavailable': 'حساس الحركة غير متاح على هذا الجهاز',
    'ringingTitle': 'المنبه يرن',
    'ringingNoMissions': 'بدون مهام — أوقف المنبه',
    'ringingStop': 'إيقاف المنبه',
    'ringingLoadFailed': 'تعذّر تحميل المهام',
    'ringingStopping': 'جارٍ الإيقاف…',
    'ringingStopFailed': 'تعذّر الإيقاف — حاول مجددًا',
    'ringingSkippedInvalid': 'تم تخطي بعض المهام (إعداد غير صالح)',
    'msgMissionInvalid': 'إعداد المهمة غير مكتمل',
    'msgMissionSaveFailed': 'تم الحفظ، لكن تعذّر حفظ المهام',
    'msgSnoozeFailed': 'تعذّرت الغفوة — حاول مجددًا',
    'securityTitle': 'الأمان',
    'pinEnable': 'تفعيل الرقم السري',
    'pinDisable': 'إيقاف الرقم السري',
    'pinChange': 'تغيير الرقم السري',
    'pinStatusEnabled': 'الرقم السري مفعّل',
    'pinStatusDisabled': 'الرقم السري متوقف',
    'pinCurrent': 'الرقم السري الحالي',
    'pinNew': 'الرقم السري الجديد',
    'pinConfirmNew': 'تأكيد الرقم السري الجديد',
    'pinEnter': 'أدخل الرقم السري',
    'pinUnlockTitle': 'أدخل الرقم السري للمتابعة',
    'pinConfirm': 'تأكيد',
    'msgPinMismatch': 'الرقم السري غير متطابق',
    'msgPinInvalid': 'يجب أن يتكون الرقم السري من 4 إلى 12 رقمًا',
    'msgPinIncorrect': 'الرقم السري غير صحيح',
    'strictDefaultLabel': 'الوضع الصارم للمنبهات الجديدة',
    'strictDefaultCaption': 'تفعيل الوضع الصارم تلقائيًا عند إنشاء منبه',
    'strictModeLabel': 'الوضع الصارم',
    'strictModeCaption': 'يجب حل المهام المطلوبة لإيقاف المنبه. لا يمنع هذا الإيقاف الإجباري أو مسح البيانات أو إطفاء الجهاز.',
    'msgStrictBlackout': 'الموعد قريب جدًا لإيقاف الوضع الصارم',
    'missionLocked': 'المهام مقفلة بالرقم السري',
    'missionUnlock': 'فتح بالرقم السري',
    'ringingSnooze': 'غفوة',
    'ringingSnoozesLeft': 'الغفوات المتبقية',
    'ringingSnoozed': 'تمت الغفوة',
    'ringingEmergencyDone': 'توقف الرنين',
    'ringingStrictLocked': 'حلّ المهام المطلوبة للإيقاف',
    'emergencyTitle': 'خروج طارئ',
    'emergencyHold': 'اضغط مطولًا 10 ثوانٍ للإيقاف',
    'emergencyUsePin': 'استخدام الرقم السري',
    'emergencyCaption': 'يوقف هذا الرنين فقط — يبقى المنبه والوضع الصارم مفعّلين.',
    'historyTitle': 'سجل المنبهات',
    'historyEmptyTitle': 'لا يوجد سجل بعد',
    'historyEmptySubtitle': 'ستظهر هنا المنبهات التي رنّت',
    'historyStatusSuccess': 'استيقاظ',
    'historyStatusFailed': 'لم يتم إيقافه',
    'historyStatusEmergency': 'إيقاف طارئ',
    'historyStatusOngoing': 'جارٍ',
    'historyStart': 'البدء',
    'historyStop': 'الإيقاف',
    'historyResult': 'النتيجة',
    'historyAttempts': 'المحاولات',
    'historySnoozes': 'الغفوات',
    'historyUnknownAlarm': 'منبه محذوف',
    'statisticsTitle': 'الإحصائيات',
    'statisticsCompleted': 'مكتملة هذا الأسبوع',
    'statisticsFailed': 'فاشلة هذا الأسبوع',
    'statisticsAverage': 'متوسط مدة الإيقاف',
    'statisticsFastest': 'أسرع إيقاف',
    'statisticsHardest': 'أصعب منبه',
    'statisticsUnavailable': 'غير متاح',
    'msgMissionsLoadFailed': 'تعذّر تحميل المهام',
    'missionFieldRequired': 'هذا الحقل مطلوب',
  };

  static const Map<String, String> _en = <String, String>{
    'appTitle': 'AlarmX',
    'homeTitle': 'Alarms',
    'homeEmptyTitle': 'No alarms yet',
    'homeEmptySubtitle': 'Add your first alarm and it will wake you on time',
    'addAlarm': 'Add alarm',
    'createAlarmTitle': 'New alarm',
    'editAlarmTitle': 'Edit alarm',
    'onLabel': 'On',
    'offLabel': 'Off',
    'nextLabel': 'Next',
    'notScheduled': 'Not scheduled',
    'labelLabel': 'Label',
    'labelHint': 'e.g. Wake up',
    'timeLabel': 'Time',
    'changeTime': 'Change time',
    'dateLabel': 'Date',
    'changeDate': 'Change date',
    'repeatLabel': 'Repeat',
    'repeatOnce': 'Once',
    'repeatDaily': 'Daily',
    'repeatCustom': 'Custom',
    'soundLabel': 'Sound',
    'soundDefault': 'Default ringtone',
    'soundCustom': 'Custom sound',
    'soundUriLabel': 'Sound link (URI)',
    'soundUriHint': 'e.g. content://...',
    'soundFutureCaption': 'Saved now; takes effect in the coming sound update',
    'volumeLabel': 'Volume',
    'vibrationLabel': 'Vibration',
    'fadeInLabel': 'Fade in gradually',
    'fadeInCaption': 'Saved now; takes effect in the coming sound update',
    'snoozeLabel': 'Snooze',
    'snoozeDuration': 'Snooze length (minutes)',
    'snoozeMaxCount': 'Maximum snoozes',
    'snoozeCaption':
        'Settings only in this version; snooze behavior arrives in a later phase',
    'missionTitle': 'Stop mission',
    'missionNone': 'No mission selected',
    'missionCaption': 'Solve missions to stop the alarm',
    'save': 'Save',
    'cancel': 'Cancel',
    'delete': 'Delete',
    'deleteTitle': 'Delete alarm?',
    'deleteMessage': 'This alarm will be unscheduled and permanently deleted.',
    'languageMenu': 'Language',
    'langArabic': 'Arabic',
    'langEnglish': 'English',
    'daySun': 'Sun',
    'dayMon': 'Mon',
    'dayTue': 'Tue',
    'dayWed': 'Wed',
    'dayThu': 'Thu',
    'dayFri': 'Fri',
    'daySat': 'Sat',
    'listSeparator': ', ',
    'msgAlarmSaved': 'Alarm saved and scheduled',
    'msgAlarmUpdated': 'Alarm updated',
    'msgAlarmDeleted': 'Alarm deleted',
    'msgAlarmEnabled': 'Alarm enabled',
    'msgAlarmDisabled': 'Alarm disabled',
    'msgAlarmMissing': 'Alarm not found',
    'msgLoadFailed': 'Could not load the alarm',
    'msgCreateFailed': 'Could not create the alarm',
    'msgUpdateFailed': 'Could not update the alarm',
    'msgDeleteFailed': 'Could not delete the alarm',
    'msgToggleFailed': 'Could not toggle the alarm',
    'msgNoPermission': 'Saved, but the exact-alarm permission is missing',
    'msgNotSchedulable': 'Saved, but this alarm has no upcoming occurrence',
    'msgScheduleFailed': 'Saved, but scheduling failed',
    'msgValidationDays': 'Select at least one day for custom repeat',
    'missionAdd': 'Add mission',
    'missionEdit': 'Edit mission',
    'missionDeleteTitle': 'Delete mission?',
    'missionDeleteMessage': 'Remove this mission from the alarm?',
    'missionRequired': 'Required',
    'missionOptional': 'Optional',
    'missionSkip': 'Skip',
    'missionMoveUp': 'Move up',
    'missionMoveDown': 'Move down',
    'missionPickType': 'Choose mission type',
    'missionTyping': 'Typing',
    'missionPhoto': 'Photo',
    'missionQr': 'QR',
    'missionBarcode': 'Barcode',
    'missionShake': 'Shake',
    'missionMath': 'Math',
    'missionProgress': 'Mission',
    'missionCompleted': 'Completed',
    'missionCorrect': 'Correct',
    'missionIncorrect': 'Incorrect, try again',
    'missionRetry': 'Try again',
    'missionCheck': 'Check',
    'missionSolve': 'Solve',
    'missionDone': 'Done',
    'typingInstruction': 'Type the text below',
    'typingHint': 'Type here',
    'typingExpectedLabel': 'Text to type',
    'photoInstruction': 'Take a photo to stop the alarm',
    'photoTake': 'Take photo',
    'photoLabel': 'What to photograph (optional)',
    'photoCancelled': 'Photo cancelled — try again',
    'photoError': 'Could not use the camera — try again',
    'qrInstruction': 'Scan the QR code',
    'qrValueLabel': 'Expected QR value',
    'barcodeInstruction': 'Scan the barcode',
    'barcodeValueLabel': 'Expected barcode value',
    'scanCancel': 'Cancel scan',
    'scanWrongCode': 'Wrong code — try again',
    'scanError': 'Scanner error — try again',
    'shakeInstruction': 'Shake your phone',
    'shakeCountLabel': 'Required shakes',
    'mathInstruction': 'Solve to stop the alarm',
    'mathAnswerHint': 'Answer',
    'mathCountLabel': 'Number of questions',
    'mathDifficultyLabel': 'Difficulty',
    'mathEasy': 'Easy',
    'mathMedium': 'Medium',
    'mathHard': 'Hard',
    'permissionCameraTitle': 'Camera permission needed',
    'permissionCameraMessage': 'Allow camera access to complete this mission',
    'permissionAllow': 'Allow',
    'permissionDenied': 'Permission denied',
    'permissionOpenSettings': 'Open settings',
    'permissionSensorMessage': 'Motion sensor access is needed for this mission',
    'sensorUnavailable': 'Motion sensor is not available on this device',
    'ringingTitle': 'Alarm ringing',
    'ringingNoMissions': 'No missions — stop the alarm',
    'ringingStop': 'Stop alarm',
    'ringingLoadFailed': 'Could not load missions',
    'ringingStopping': 'Stopping…',
    'ringingStopFailed': 'Could not stop — try again',
    'ringingSkippedInvalid': 'Some missions were skipped (invalid setup)',
    'msgMissionInvalid': 'Mission setup is incomplete',
    'msgMissionSaveFailed': 'Saved, but missions could not be saved',
    'msgSnoozeFailed': 'Could not snooze — try again',
    'securityTitle': 'Security',
    'pinEnable': 'Enable PIN',
    'pinDisable': 'Disable PIN',
    'pinChange': 'Change PIN',
    'pinStatusEnabled': 'PIN is on',
    'pinStatusDisabled': 'PIN is off',
    'pinCurrent': 'Current PIN',
    'pinNew': 'New PIN',
    'pinConfirmNew': 'Confirm new PIN',
    'pinEnter': 'Enter PIN',
    'pinUnlockTitle': 'Enter PIN to continue',
    'pinConfirm': 'Confirm',
    'msgPinMismatch': 'PINs do not match',
    'msgPinInvalid': 'PIN must be 4–12 digits',
    'msgPinIncorrect': 'Incorrect PIN',
    'strictDefaultLabel': 'Strict Mode for new alarms',
    'strictDefaultCaption': 'Turn Strict Mode on automatically for new alarms',
    'strictModeLabel': 'Strict Mode',
    'strictModeCaption': 'Required missions must be solved to stop. This does not prevent Force Stop, Clear Data, or Power Off.',
    'msgStrictBlackout': 'Too close to the next ring to switch Strict Mode off',
    'missionLocked': 'Missions are PIN-locked',
    'missionUnlock': 'Unlock with PIN',
    'ringingSnooze': 'Snooze',
    'ringingSnoozesLeft': 'Snoozes left',
    'ringingSnoozed': 'Snoozed',
    'ringingEmergencyDone': 'Ring stopped',
    'ringingStrictLocked': 'Solve the required missions to stop',
    'emergencyTitle': 'Emergency exit',
    'emergencyHold': 'Hold 10 seconds to force-stop',
    'emergencyUsePin': 'Use PIN instead',
    'emergencyCaption': 'Stops this ring only — the alarm and Strict Mode stay on.',
    'historyTitle': 'Alarm history',
    'historyEmptyTitle': 'No history yet',
    'historyEmptySubtitle': 'Rings will appear here',
    'historyStatusSuccess': 'Wake-up',
    'historyStatusFailed': 'Not stopped',
    'historyStatusEmergency': 'Emergency Stop',
    'historyStatusOngoing': 'Ongoing',
    'historyStart': 'Started',
    'historyStop': 'Stopped',
    'historyResult': 'Result',
    'historyAttempts': 'Attempts',
    'historySnoozes': 'Snoozes',
    'historyUnknownAlarm': 'Deleted alarm',
    'statisticsTitle': 'Statistics',
    'statisticsCompleted': 'Completed this week',
    'statisticsFailed': 'Failed this week',
    'statisticsAverage': 'Average stop time',
    'statisticsFastest': 'Fastest stop',
    'statisticsHardest': 'Hardest alarm',
    'statisticsUnavailable': 'Unavailable',
    'msgMissionsLoadFailed': 'Could not load missions',
    'missionFieldRequired': 'This field is required',
  };
}
