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
    'missionCaption': 'المهام تصل في مرحلة قادمة',
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
    'missionCaption': 'Missions arrive in a later phase',
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
  };
}
