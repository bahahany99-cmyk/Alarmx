// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AlarmsTable extends Alarms with TableInfo<$AlarmsTable, Alarm> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
    'minute',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _repeatTypeMeta = const VerificationMeta(
    'repeatType',
  );
  @override
  late final GeneratedColumn<String> repeatType = GeneratedColumn<String>(
    'repeat_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('once'),
  );
  static const VerificationMeta _repeatDaysMeta = const VerificationMeta(
    'repeatDays',
  );
  @override
  late final GeneratedColumn<int> repeatDays = GeneratedColumn<int>(
    'repeat_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onceDateMeta = const VerificationMeta(
    'onceDate',
  );
  @override
  late final GeneratedColumn<DateTime> onceDate = GeneratedColumn<DateTime>(
    'once_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soundUriMeta = const VerificationMeta(
    'soundUri',
  );
  @override
  late final GeneratedColumn<String> soundUri = GeneratedColumn<String>(
    'sound_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soundTypeMeta = const VerificationMeta(
    'soundType',
  );
  @override
  late final GeneratedColumn<String> soundType = GeneratedColumn<String>(
    'sound_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('default'),
  );
  static const VerificationMeta _volumeMeta = const VerificationMeta('volume');
  @override
  late final GeneratedColumn<int> volume = GeneratedColumn<int>(
    'volume',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(80),
  );
  static const VerificationMeta _fadeInEnabledMeta = const VerificationMeta(
    'fadeInEnabled',
  );
  @override
  late final GeneratedColumn<bool> fadeInEnabled = GeneratedColumn<bool>(
    'fade_in_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fade_in_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _vibrationEnabledMeta = const VerificationMeta(
    'vibrationEnabled',
  );
  @override
  late final GeneratedColumn<bool> vibrationEnabled = GeneratedColumn<bool>(
    'vibration_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vibration_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _snoozeEnabledMeta = const VerificationMeta(
    'snoozeEnabled',
  );
  @override
  late final GeneratedColumn<bool> snoozeEnabled = GeneratedColumn<bool>(
    'snooze_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("snooze_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _snoozeMinutesMeta = const VerificationMeta(
    'snoozeMinutes',
  );
  @override
  late final GeneratedColumn<int> snoozeMinutes = GeneratedColumn<int>(
    'snooze_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _snoozeMaxCountMeta = const VerificationMeta(
    'snoozeMaxCount',
  );
  @override
  late final GeneratedColumn<int> snoozeMaxCount = GeneratedColumn<int>(
    'snooze_max_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _strictModeMeta = const VerificationMeta(
    'strictMode',
  );
  @override
  late final GeneratedColumn<bool> strictMode = GeneratedColumn<bool>(
    'strict_mode',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("strict_mode" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _nextTriggerAtMeta = const VerificationMeta(
    'nextTriggerAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextTriggerAt =
      GeneratedColumn<DateTime>(
        'next_trigger_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    hour,
    minute,
    enabled,
    repeatType,
    repeatDays,
    onceDate,
    soundUri,
    soundType,
    volume,
    fadeInEnabled,
    vibrationEnabled,
    snoozeEnabled,
    snoozeMinutes,
    snoozeMaxCount,
    strictMode,
    nextTriggerAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarms';
  @override
  VerificationContext validateIntegrity(
    Insertable<Alarm> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('hour')) {
      context.handle(
        _hourMeta,
        hour.isAcceptableOrUnknown(data['hour']!, _hourMeta),
      );
    } else if (isInserting) {
      context.missing(_hourMeta);
    }
    if (data.containsKey('minute')) {
      context.handle(
        _minuteMeta,
        minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta),
      );
    } else if (isInserting) {
      context.missing(_minuteMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('repeat_type')) {
      context.handle(
        _repeatTypeMeta,
        repeatType.isAcceptableOrUnknown(data['repeat_type']!, _repeatTypeMeta),
      );
    }
    if (data.containsKey('repeat_days')) {
      context.handle(
        _repeatDaysMeta,
        repeatDays.isAcceptableOrUnknown(data['repeat_days']!, _repeatDaysMeta),
      );
    }
    if (data.containsKey('once_date')) {
      context.handle(
        _onceDateMeta,
        onceDate.isAcceptableOrUnknown(data['once_date']!, _onceDateMeta),
      );
    }
    if (data.containsKey('sound_uri')) {
      context.handle(
        _soundUriMeta,
        soundUri.isAcceptableOrUnknown(data['sound_uri']!, _soundUriMeta),
      );
    }
    if (data.containsKey('sound_type')) {
      context.handle(
        _soundTypeMeta,
        soundType.isAcceptableOrUnknown(data['sound_type']!, _soundTypeMeta),
      );
    }
    if (data.containsKey('volume')) {
      context.handle(
        _volumeMeta,
        volume.isAcceptableOrUnknown(data['volume']!, _volumeMeta),
      );
    }
    if (data.containsKey('fade_in_enabled')) {
      context.handle(
        _fadeInEnabledMeta,
        fadeInEnabled.isAcceptableOrUnknown(
          data['fade_in_enabled']!,
          _fadeInEnabledMeta,
        ),
      );
    }
    if (data.containsKey('vibration_enabled')) {
      context.handle(
        _vibrationEnabledMeta,
        vibrationEnabled.isAcceptableOrUnknown(
          data['vibration_enabled']!,
          _vibrationEnabledMeta,
        ),
      );
    }
    if (data.containsKey('snooze_enabled')) {
      context.handle(
        _snoozeEnabledMeta,
        snoozeEnabled.isAcceptableOrUnknown(
          data['snooze_enabled']!,
          _snoozeEnabledMeta,
        ),
      );
    }
    if (data.containsKey('snooze_minutes')) {
      context.handle(
        _snoozeMinutesMeta,
        snoozeMinutes.isAcceptableOrUnknown(
          data['snooze_minutes']!,
          _snoozeMinutesMeta,
        ),
      );
    }
    if (data.containsKey('snooze_max_count')) {
      context.handle(
        _snoozeMaxCountMeta,
        snoozeMaxCount.isAcceptableOrUnknown(
          data['snooze_max_count']!,
          _snoozeMaxCountMeta,
        ),
      );
    }
    if (data.containsKey('strict_mode')) {
      context.handle(
        _strictModeMeta,
        strictMode.isAcceptableOrUnknown(data['strict_mode']!, _strictModeMeta),
      );
    }
    if (data.containsKey('next_trigger_at')) {
      context.handle(
        _nextTriggerAtMeta,
        nextTriggerAt.isAcceptableOrUnknown(
          data['next_trigger_at']!,
          _nextTriggerAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Alarm map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Alarm(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      hour: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hour'],
      )!,
      minute: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minute'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      repeatType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repeat_type'],
      )!,
      repeatDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repeat_days'],
      ),
      onceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}once_date'],
      ),
      soundUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sound_uri'],
      ),
      soundType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sound_type'],
      )!,
      volume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}volume'],
      )!,
      fadeInEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fade_in_enabled'],
      )!,
      vibrationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vibration_enabled'],
      )!,
      snoozeEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}snooze_enabled'],
      )!,
      snoozeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_minutes'],
      )!,
      snoozeMaxCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_max_count'],
      )!,
      strictMode: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}strict_mode'],
      )!,
      nextTriggerAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_trigger_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AlarmsTable createAlias(String alias) {
    return $AlarmsTable(attachedDatabase, alias);
  }
}

class Alarm extends DataClass implements Insertable<Alarm> {
  final int id;
  final String? label;
  final int hour;
  final int minute;
  final bool enabled;
  final String repeatType;
  final int? repeatDays;
  final DateTime? onceDate;
  final String? soundUri;
  final String soundType;
  final int volume;
  final bool fadeInEnabled;
  final bool vibrationEnabled;
  final bool snoozeEnabled;
  final int snoozeMinutes;
  final int snoozeMaxCount;
  final bool strictMode;
  final DateTime? nextTriggerAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Alarm({
    required this.id,
    this.label,
    required this.hour,
    required this.minute,
    required this.enabled,
    required this.repeatType,
    this.repeatDays,
    this.onceDate,
    this.soundUri,
    required this.soundType,
    required this.volume,
    required this.fadeInEnabled,
    required this.vibrationEnabled,
    required this.snoozeEnabled,
    required this.snoozeMinutes,
    required this.snoozeMaxCount,
    required this.strictMode,
    this.nextTriggerAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['enabled'] = Variable<bool>(enabled);
    map['repeat_type'] = Variable<String>(repeatType);
    if (!nullToAbsent || repeatDays != null) {
      map['repeat_days'] = Variable<int>(repeatDays);
    }
    if (!nullToAbsent || onceDate != null) {
      map['once_date'] = Variable<DateTime>(onceDate);
    }
    if (!nullToAbsent || soundUri != null) {
      map['sound_uri'] = Variable<String>(soundUri);
    }
    map['sound_type'] = Variable<String>(soundType);
    map['volume'] = Variable<int>(volume);
    map['fade_in_enabled'] = Variable<bool>(fadeInEnabled);
    map['vibration_enabled'] = Variable<bool>(vibrationEnabled);
    map['snooze_enabled'] = Variable<bool>(snoozeEnabled);
    map['snooze_minutes'] = Variable<int>(snoozeMinutes);
    map['snooze_max_count'] = Variable<int>(snoozeMaxCount);
    map['strict_mode'] = Variable<bool>(strictMode);
    if (!nullToAbsent || nextTriggerAt != null) {
      map['next_trigger_at'] = Variable<DateTime>(nextTriggerAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AlarmsCompanion toCompanion(bool nullToAbsent) {
    return AlarmsCompanion(
      id: Value(id),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      hour: Value(hour),
      minute: Value(minute),
      enabled: Value(enabled),
      repeatType: Value(repeatType),
      repeatDays: repeatDays == null && nullToAbsent
          ? const Value.absent()
          : Value(repeatDays),
      onceDate: onceDate == null && nullToAbsent
          ? const Value.absent()
          : Value(onceDate),
      soundUri: soundUri == null && nullToAbsent
          ? const Value.absent()
          : Value(soundUri),
      soundType: Value(soundType),
      volume: Value(volume),
      fadeInEnabled: Value(fadeInEnabled),
      vibrationEnabled: Value(vibrationEnabled),
      snoozeEnabled: Value(snoozeEnabled),
      snoozeMinutes: Value(snoozeMinutes),
      snoozeMaxCount: Value(snoozeMaxCount),
      strictMode: Value(strictMode),
      nextTriggerAt: nextTriggerAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextTriggerAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Alarm.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Alarm(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String?>(json['label']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      repeatType: serializer.fromJson<String>(json['repeatType']),
      repeatDays: serializer.fromJson<int?>(json['repeatDays']),
      onceDate: serializer.fromJson<DateTime?>(json['onceDate']),
      soundUri: serializer.fromJson<String?>(json['soundUri']),
      soundType: serializer.fromJson<String>(json['soundType']),
      volume: serializer.fromJson<int>(json['volume']),
      fadeInEnabled: serializer.fromJson<bool>(json['fadeInEnabled']),
      vibrationEnabled: serializer.fromJson<bool>(json['vibrationEnabled']),
      snoozeEnabled: serializer.fromJson<bool>(json['snoozeEnabled']),
      snoozeMinutes: serializer.fromJson<int>(json['snoozeMinutes']),
      snoozeMaxCount: serializer.fromJson<int>(json['snoozeMaxCount']),
      strictMode: serializer.fromJson<bool>(json['strictMode']),
      nextTriggerAt: serializer.fromJson<DateTime?>(json['nextTriggerAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String?>(label),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'enabled': serializer.toJson<bool>(enabled),
      'repeatType': serializer.toJson<String>(repeatType),
      'repeatDays': serializer.toJson<int?>(repeatDays),
      'onceDate': serializer.toJson<DateTime?>(onceDate),
      'soundUri': serializer.toJson<String?>(soundUri),
      'soundType': serializer.toJson<String>(soundType),
      'volume': serializer.toJson<int>(volume),
      'fadeInEnabled': serializer.toJson<bool>(fadeInEnabled),
      'vibrationEnabled': serializer.toJson<bool>(vibrationEnabled),
      'snoozeEnabled': serializer.toJson<bool>(snoozeEnabled),
      'snoozeMinutes': serializer.toJson<int>(snoozeMinutes),
      'snoozeMaxCount': serializer.toJson<int>(snoozeMaxCount),
      'strictMode': serializer.toJson<bool>(strictMode),
      'nextTriggerAt': serializer.toJson<DateTime?>(nextTriggerAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Alarm copyWith({
    int? id,
    Value<String?> label = const Value.absent(),
    int? hour,
    int? minute,
    bool? enabled,
    String? repeatType,
    Value<int?> repeatDays = const Value.absent(),
    Value<DateTime?> onceDate = const Value.absent(),
    Value<String?> soundUri = const Value.absent(),
    String? soundType,
    int? volume,
    bool? fadeInEnabled,
    bool? vibrationEnabled,
    bool? snoozeEnabled,
    int? snoozeMinutes,
    int? snoozeMaxCount,
    bool? strictMode,
    Value<DateTime?> nextTriggerAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Alarm(
    id: id ?? this.id,
    label: label.present ? label.value : this.label,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    enabled: enabled ?? this.enabled,
    repeatType: repeatType ?? this.repeatType,
    repeatDays: repeatDays.present ? repeatDays.value : this.repeatDays,
    onceDate: onceDate.present ? onceDate.value : this.onceDate,
    soundUri: soundUri.present ? soundUri.value : this.soundUri,
    soundType: soundType ?? this.soundType,
    volume: volume ?? this.volume,
    fadeInEnabled: fadeInEnabled ?? this.fadeInEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    snoozeMaxCount: snoozeMaxCount ?? this.snoozeMaxCount,
    strictMode: strictMode ?? this.strictMode,
    nextTriggerAt: nextTriggerAt.present
        ? nextTriggerAt.value
        : this.nextTriggerAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Alarm copyWithCompanion(AlarmsCompanion data) {
    return Alarm(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      repeatType: data.repeatType.present
          ? data.repeatType.value
          : this.repeatType,
      repeatDays: data.repeatDays.present
          ? data.repeatDays.value
          : this.repeatDays,
      onceDate: data.onceDate.present ? data.onceDate.value : this.onceDate,
      soundUri: data.soundUri.present ? data.soundUri.value : this.soundUri,
      soundType: data.soundType.present ? data.soundType.value : this.soundType,
      volume: data.volume.present ? data.volume.value : this.volume,
      fadeInEnabled: data.fadeInEnabled.present
          ? data.fadeInEnabled.value
          : this.fadeInEnabled,
      vibrationEnabled: data.vibrationEnabled.present
          ? data.vibrationEnabled.value
          : this.vibrationEnabled,
      snoozeEnabled: data.snoozeEnabled.present
          ? data.snoozeEnabled.value
          : this.snoozeEnabled,
      snoozeMinutes: data.snoozeMinutes.present
          ? data.snoozeMinutes.value
          : this.snoozeMinutes,
      snoozeMaxCount: data.snoozeMaxCount.present
          ? data.snoozeMaxCount.value
          : this.snoozeMaxCount,
      strictMode: data.strictMode.present
          ? data.strictMode.value
          : this.strictMode,
      nextTriggerAt: data.nextTriggerAt.present
          ? data.nextTriggerAt.value
          : this.nextTriggerAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Alarm(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('enabled: $enabled, ')
          ..write('repeatType: $repeatType, ')
          ..write('repeatDays: $repeatDays, ')
          ..write('onceDate: $onceDate, ')
          ..write('soundUri: $soundUri, ')
          ..write('soundType: $soundType, ')
          ..write('volume: $volume, ')
          ..write('fadeInEnabled: $fadeInEnabled, ')
          ..write('vibrationEnabled: $vibrationEnabled, ')
          ..write('snoozeEnabled: $snoozeEnabled, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('snoozeMaxCount: $snoozeMaxCount, ')
          ..write('strictMode: $strictMode, ')
          ..write('nextTriggerAt: $nextTriggerAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    hour,
    minute,
    enabled,
    repeatType,
    repeatDays,
    onceDate,
    soundUri,
    soundType,
    volume,
    fadeInEnabled,
    vibrationEnabled,
    snoozeEnabled,
    snoozeMinutes,
    snoozeMaxCount,
    strictMode,
    nextTriggerAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Alarm &&
          other.id == this.id &&
          other.label == this.label &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.enabled == this.enabled &&
          other.repeatType == this.repeatType &&
          other.repeatDays == this.repeatDays &&
          other.onceDate == this.onceDate &&
          other.soundUri == this.soundUri &&
          other.soundType == this.soundType &&
          other.volume == this.volume &&
          other.fadeInEnabled == this.fadeInEnabled &&
          other.vibrationEnabled == this.vibrationEnabled &&
          other.snoozeEnabled == this.snoozeEnabled &&
          other.snoozeMinutes == this.snoozeMinutes &&
          other.snoozeMaxCount == this.snoozeMaxCount &&
          other.strictMode == this.strictMode &&
          other.nextTriggerAt == this.nextTriggerAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AlarmsCompanion extends UpdateCompanion<Alarm> {
  final Value<int> id;
  final Value<String?> label;
  final Value<int> hour;
  final Value<int> minute;
  final Value<bool> enabled;
  final Value<String> repeatType;
  final Value<int?> repeatDays;
  final Value<DateTime?> onceDate;
  final Value<String?> soundUri;
  final Value<String> soundType;
  final Value<int> volume;
  final Value<bool> fadeInEnabled;
  final Value<bool> vibrationEnabled;
  final Value<bool> snoozeEnabled;
  final Value<int> snoozeMinutes;
  final Value<int> snoozeMaxCount;
  final Value<bool> strictMode;
  final Value<DateTime?> nextTriggerAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const AlarmsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.enabled = const Value.absent(),
    this.repeatType = const Value.absent(),
    this.repeatDays = const Value.absent(),
    this.onceDate = const Value.absent(),
    this.soundUri = const Value.absent(),
    this.soundType = const Value.absent(),
    this.volume = const Value.absent(),
    this.fadeInEnabled = const Value.absent(),
    this.vibrationEnabled = const Value.absent(),
    this.snoozeEnabled = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.snoozeMaxCount = const Value.absent(),
    this.strictMode = const Value.absent(),
    this.nextTriggerAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  AlarmsCompanion.insert({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    required int hour,
    required int minute,
    this.enabled = const Value.absent(),
    this.repeatType = const Value.absent(),
    this.repeatDays = const Value.absent(),
    this.onceDate = const Value.absent(),
    this.soundUri = const Value.absent(),
    this.soundType = const Value.absent(),
    this.volume = const Value.absent(),
    this.fadeInEnabled = const Value.absent(),
    this.vibrationEnabled = const Value.absent(),
    this.snoozeEnabled = const Value.absent(),
    this.snoozeMinutes = const Value.absent(),
    this.snoozeMaxCount = const Value.absent(),
    this.strictMode = const Value.absent(),
    this.nextTriggerAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : hour = Value(hour),
       minute = Value(minute);
  static Insertable<Alarm> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<bool>? enabled,
    Expression<String>? repeatType,
    Expression<int>? repeatDays,
    Expression<DateTime>? onceDate,
    Expression<String>? soundUri,
    Expression<String>? soundType,
    Expression<int>? volume,
    Expression<bool>? fadeInEnabled,
    Expression<bool>? vibrationEnabled,
    Expression<bool>? snoozeEnabled,
    Expression<int>? snoozeMinutes,
    Expression<int>? snoozeMaxCount,
    Expression<bool>? strictMode,
    Expression<DateTime>? nextTriggerAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (enabled != null) 'enabled': enabled,
      if (repeatType != null) 'repeat_type': repeatType,
      if (repeatDays != null) 'repeat_days': repeatDays,
      if (onceDate != null) 'once_date': onceDate,
      if (soundUri != null) 'sound_uri': soundUri,
      if (soundType != null) 'sound_type': soundType,
      if (volume != null) 'volume': volume,
      if (fadeInEnabled != null) 'fade_in_enabled': fadeInEnabled,
      if (vibrationEnabled != null) 'vibration_enabled': vibrationEnabled,
      if (snoozeEnabled != null) 'snooze_enabled': snoozeEnabled,
      if (snoozeMinutes != null) 'snooze_minutes': snoozeMinutes,
      if (snoozeMaxCount != null) 'snooze_max_count': snoozeMaxCount,
      if (strictMode != null) 'strict_mode': strictMode,
      if (nextTriggerAt != null) 'next_trigger_at': nextTriggerAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  AlarmsCompanion copyWith({
    Value<int>? id,
    Value<String?>? label,
    Value<int>? hour,
    Value<int>? minute,
    Value<bool>? enabled,
    Value<String>? repeatType,
    Value<int?>? repeatDays,
    Value<DateTime?>? onceDate,
    Value<String?>? soundUri,
    Value<String>? soundType,
    Value<int>? volume,
    Value<bool>? fadeInEnabled,
    Value<bool>? vibrationEnabled,
    Value<bool>? snoozeEnabled,
    Value<int>? snoozeMinutes,
    Value<int>? snoozeMaxCount,
    Value<bool>? strictMode,
    Value<DateTime?>? nextTriggerAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return AlarmsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      enabled: enabled ?? this.enabled,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      onceDate: onceDate ?? this.onceDate,
      soundUri: soundUri ?? this.soundUri,
      soundType: soundType ?? this.soundType,
      volume: volume ?? this.volume,
      fadeInEnabled: fadeInEnabled ?? this.fadeInEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      snoozeMaxCount: snoozeMaxCount ?? this.snoozeMaxCount,
      strictMode: strictMode ?? this.strictMode,
      nextTriggerAt: nextTriggerAt ?? this.nextTriggerAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (repeatType.present) {
      map['repeat_type'] = Variable<String>(repeatType.value);
    }
    if (repeatDays.present) {
      map['repeat_days'] = Variable<int>(repeatDays.value);
    }
    if (onceDate.present) {
      map['once_date'] = Variable<DateTime>(onceDate.value);
    }
    if (soundUri.present) {
      map['sound_uri'] = Variable<String>(soundUri.value);
    }
    if (soundType.present) {
      map['sound_type'] = Variable<String>(soundType.value);
    }
    if (volume.present) {
      map['volume'] = Variable<int>(volume.value);
    }
    if (fadeInEnabled.present) {
      map['fade_in_enabled'] = Variable<bool>(fadeInEnabled.value);
    }
    if (vibrationEnabled.present) {
      map['vibration_enabled'] = Variable<bool>(vibrationEnabled.value);
    }
    if (snoozeEnabled.present) {
      map['snooze_enabled'] = Variable<bool>(snoozeEnabled.value);
    }
    if (snoozeMinutes.present) {
      map['snooze_minutes'] = Variable<int>(snoozeMinutes.value);
    }
    if (snoozeMaxCount.present) {
      map['snooze_max_count'] = Variable<int>(snoozeMaxCount.value);
    }
    if (strictMode.present) {
      map['strict_mode'] = Variable<bool>(strictMode.value);
    }
    if (nextTriggerAt.present) {
      map['next_trigger_at'] = Variable<DateTime>(nextTriggerAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('enabled: $enabled, ')
          ..write('repeatType: $repeatType, ')
          ..write('repeatDays: $repeatDays, ')
          ..write('onceDate: $onceDate, ')
          ..write('soundUri: $soundUri, ')
          ..write('soundType: $soundType, ')
          ..write('volume: $volume, ')
          ..write('fadeInEnabled: $fadeInEnabled, ')
          ..write('vibrationEnabled: $vibrationEnabled, ')
          ..write('snoozeEnabled: $snoozeEnabled, ')
          ..write('snoozeMinutes: $snoozeMinutes, ')
          ..write('snoozeMaxCount: $snoozeMaxCount, ')
          ..write('strictMode: $strictMode, ')
          ..write('nextTriggerAt: $nextTriggerAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MissionsTable extends Missions with TableInfo<$MissionsTable, Mission> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _alarmIdMeta = const VerificationMeta(
    'alarmId',
  );
  @override
  late final GeneratedColumn<int> alarmId = GeneratedColumn<int>(
    'alarm_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES alarms (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _requiredMeta = const VerificationMeta(
    'required',
  );
  @override
  late final GeneratedColumn<bool> required = GeneratedColumn<bool>(
    'required',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("required" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    alarmId,
    type,
    orderIndex,
    configJson,
    required,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'missions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mission> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('alarm_id')) {
      context.handle(
        _alarmIdMeta,
        alarmId.isAcceptableOrUnknown(data['alarm_id']!, _alarmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_alarmIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    }
    if (data.containsKey('required')) {
      context.handle(
        _requiredMeta,
        required.isAcceptableOrUnknown(data['required']!, _requiredMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mission map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mission(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      alarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alarm_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      ),
      required: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}required'],
      )!,
    );
  }

  @override
  $MissionsTable createAlias(String alias) {
    return $MissionsTable(attachedDatabase, alias);
  }
}

class Mission extends DataClass implements Insertable<Mission> {
  final int id;
  final int alarmId;
  final String type;
  final int orderIndex;
  final String? configJson;
  final bool required;
  const Mission({
    required this.id,
    required this.alarmId,
    required this.type,
    required this.orderIndex,
    this.configJson,
    required this.required,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['alarm_id'] = Variable<int>(alarmId);
    map['type'] = Variable<String>(type);
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || configJson != null) {
      map['config_json'] = Variable<String>(configJson);
    }
    map['required'] = Variable<bool>(required);
    return map;
  }

  MissionsCompanion toCompanion(bool nullToAbsent) {
    return MissionsCompanion(
      id: Value(id),
      alarmId: Value(alarmId),
      type: Value(type),
      orderIndex: Value(orderIndex),
      configJson: configJson == null && nullToAbsent
          ? const Value.absent()
          : Value(configJson),
      required: Value(required),
    );
  }

  factory Mission.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mission(
      id: serializer.fromJson<int>(json['id']),
      alarmId: serializer.fromJson<int>(json['alarmId']),
      type: serializer.fromJson<String>(json['type']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      configJson: serializer.fromJson<String?>(json['configJson']),
      required: serializer.fromJson<bool>(json['required']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'alarmId': serializer.toJson<int>(alarmId),
      'type': serializer.toJson<String>(type),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'configJson': serializer.toJson<String?>(configJson),
      'required': serializer.toJson<bool>(required),
    };
  }

  Mission copyWith({
    int? id,
    int? alarmId,
    String? type,
    int? orderIndex,
    Value<String?> configJson = const Value.absent(),
    bool? required,
  }) => Mission(
    id: id ?? this.id,
    alarmId: alarmId ?? this.alarmId,
    type: type ?? this.type,
    orderIndex: orderIndex ?? this.orderIndex,
    configJson: configJson.present ? configJson.value : this.configJson,
    required: required ?? this.required,
  );
  Mission copyWithCompanion(MissionsCompanion data) {
    return Mission(
      id: data.id.present ? data.id.value : this.id,
      alarmId: data.alarmId.present ? data.alarmId.value : this.alarmId,
      type: data.type.present ? data.type.value : this.type,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      required: data.required.present ? data.required.value : this.required,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mission(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('type: $type, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('configJson: $configJson, ')
          ..write('required: $required')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, alarmId, type, orderIndex, configJson, required);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mission &&
          other.id == this.id &&
          other.alarmId == this.alarmId &&
          other.type == this.type &&
          other.orderIndex == this.orderIndex &&
          other.configJson == this.configJson &&
          other.required == this.required);
}

class MissionsCompanion extends UpdateCompanion<Mission> {
  final Value<int> id;
  final Value<int> alarmId;
  final Value<String> type;
  final Value<int> orderIndex;
  final Value<String?> configJson;
  final Value<bool> required;
  const MissionsCompanion({
    this.id = const Value.absent(),
    this.alarmId = const Value.absent(),
    this.type = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.configJson = const Value.absent(),
    this.required = const Value.absent(),
  });
  MissionsCompanion.insert({
    this.id = const Value.absent(),
    required int alarmId,
    required String type,
    this.orderIndex = const Value.absent(),
    this.configJson = const Value.absent(),
    this.required = const Value.absent(),
  }) : alarmId = Value(alarmId),
       type = Value(type);
  static Insertable<Mission> custom({
    Expression<int>? id,
    Expression<int>? alarmId,
    Expression<String>? type,
    Expression<int>? orderIndex,
    Expression<String>? configJson,
    Expression<bool>? required,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alarmId != null) 'alarm_id': alarmId,
      if (type != null) 'type': type,
      if (orderIndex != null) 'order_index': orderIndex,
      if (configJson != null) 'config_json': configJson,
      if (required != null) 'required': required,
    });
  }

  MissionsCompanion copyWith({
    Value<int>? id,
    Value<int>? alarmId,
    Value<String>? type,
    Value<int>? orderIndex,
    Value<String?>? configJson,
    Value<bool>? required,
  }) {
    return MissionsCompanion(
      id: id ?? this.id,
      alarmId: alarmId ?? this.alarmId,
      type: type ?? this.type,
      orderIndex: orderIndex ?? this.orderIndex,
      configJson: configJson ?? this.configJson,
      required: required ?? this.required,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (alarmId.present) {
      map['alarm_id'] = Variable<int>(alarmId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (required.present) {
      map['required'] = Variable<bool>(required.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissionsCompanion(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('type: $type, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('configJson: $configJson, ')
          ..write('required: $required')
          ..write(')'))
        .toString();
  }
}

class $AlarmHistoryTable extends AlarmHistory
    with TableInfo<$AlarmHistoryTable, AlarmHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlarmHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _alarmIdMeta = const VerificationMeta(
    'alarmId',
  );
  @override
  late final GeneratedColumn<int> alarmId = GeneratedColumn<int>(
    'alarm_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stoppedAtMeta = const VerificationMeta(
    'stoppedAt',
  );
  @override
  late final GeneratedColumn<DateTime> stoppedAt = GeneratedColumn<DateTime>(
    'stopped_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ongoing'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _snoozeCountMeta = const VerificationMeta(
    'snoozeCount',
  );
  @override
  late final GeneratedColumn<int> snoozeCount = GeneratedColumn<int>(
    'snooze_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    alarmId,
    startedAt,
    stoppedAt,
    result,
    attempts,
    snoozeCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alarm_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlarmHistoryData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('alarm_id')) {
      context.handle(
        _alarmIdMeta,
        alarmId.isAcceptableOrUnknown(data['alarm_id']!, _alarmIdMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('stopped_at')) {
      context.handle(
        _stoppedAtMeta,
        stoppedAt.isAcceptableOrUnknown(data['stopped_at']!, _stoppedAtMeta),
      );
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('snooze_count')) {
      context.handle(
        _snoozeCountMeta,
        snoozeCount.isAcceptableOrUnknown(
          data['snooze_count']!,
          _snoozeCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlarmHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlarmHistoryData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      alarmId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}alarm_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      stoppedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}stopped_at'],
      ),
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      snoozeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_count'],
      )!,
    );
  }

  @override
  $AlarmHistoryTable createAlias(String alias) {
    return $AlarmHistoryTable(attachedDatabase, alias);
  }
}

class AlarmHistoryData extends DataClass
    implements Insertable<AlarmHistoryData> {
  final int id;
  final int? alarmId;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final String result;
  final int attempts;
  final int snoozeCount;
  const AlarmHistoryData({
    required this.id,
    this.alarmId,
    required this.startedAt,
    this.stoppedAt,
    required this.result,
    required this.attempts,
    required this.snoozeCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || alarmId != null) {
      map['alarm_id'] = Variable<int>(alarmId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || stoppedAt != null) {
      map['stopped_at'] = Variable<DateTime>(stoppedAt);
    }
    map['result'] = Variable<String>(result);
    map['attempts'] = Variable<int>(attempts);
    map['snooze_count'] = Variable<int>(snoozeCount);
    return map;
  }

  AlarmHistoryCompanion toCompanion(bool nullToAbsent) {
    return AlarmHistoryCompanion(
      id: Value(id),
      alarmId: alarmId == null && nullToAbsent
          ? const Value.absent()
          : Value(alarmId),
      startedAt: Value(startedAt),
      stoppedAt: stoppedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(stoppedAt),
      result: Value(result),
      attempts: Value(attempts),
      snoozeCount: Value(snoozeCount),
    );
  }

  factory AlarmHistoryData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlarmHistoryData(
      id: serializer.fromJson<int>(json['id']),
      alarmId: serializer.fromJson<int?>(json['alarmId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      stoppedAt: serializer.fromJson<DateTime?>(json['stoppedAt']),
      result: serializer.fromJson<String>(json['result']),
      attempts: serializer.fromJson<int>(json['attempts']),
      snoozeCount: serializer.fromJson<int>(json['snoozeCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'alarmId': serializer.toJson<int?>(alarmId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'stoppedAt': serializer.toJson<DateTime?>(stoppedAt),
      'result': serializer.toJson<String>(result),
      'attempts': serializer.toJson<int>(attempts),
      'snoozeCount': serializer.toJson<int>(snoozeCount),
    };
  }

  AlarmHistoryData copyWith({
    int? id,
    Value<int?> alarmId = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> stoppedAt = const Value.absent(),
    String? result,
    int? attempts,
    int? snoozeCount,
  }) => AlarmHistoryData(
    id: id ?? this.id,
    alarmId: alarmId.present ? alarmId.value : this.alarmId,
    startedAt: startedAt ?? this.startedAt,
    stoppedAt: stoppedAt.present ? stoppedAt.value : this.stoppedAt,
    result: result ?? this.result,
    attempts: attempts ?? this.attempts,
    snoozeCount: snoozeCount ?? this.snoozeCount,
  );
  AlarmHistoryData copyWithCompanion(AlarmHistoryCompanion data) {
    return AlarmHistoryData(
      id: data.id.present ? data.id.value : this.id,
      alarmId: data.alarmId.present ? data.alarmId.value : this.alarmId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      stoppedAt: data.stoppedAt.present ? data.stoppedAt.value : this.stoppedAt,
      result: data.result.present ? data.result.value : this.result,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      snoozeCount: data.snoozeCount.present
          ? data.snoozeCount.value
          : this.snoozeCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlarmHistoryData(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('startedAt: $startedAt, ')
          ..write('stoppedAt: $stoppedAt, ')
          ..write('result: $result, ')
          ..write('attempts: $attempts, ')
          ..write('snoozeCount: $snoozeCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    alarmId,
    startedAt,
    stoppedAt,
    result,
    attempts,
    snoozeCount,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlarmHistoryData &&
          other.id == this.id &&
          other.alarmId == this.alarmId &&
          other.startedAt == this.startedAt &&
          other.stoppedAt == this.stoppedAt &&
          other.result == this.result &&
          other.attempts == this.attempts &&
          other.snoozeCount == this.snoozeCount);
}

class AlarmHistoryCompanion extends UpdateCompanion<AlarmHistoryData> {
  final Value<int> id;
  final Value<int?> alarmId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> stoppedAt;
  final Value<String> result;
  final Value<int> attempts;
  final Value<int> snoozeCount;
  const AlarmHistoryCompanion({
    this.id = const Value.absent(),
    this.alarmId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.stoppedAt = const Value.absent(),
    this.result = const Value.absent(),
    this.attempts = const Value.absent(),
    this.snoozeCount = const Value.absent(),
  });
  AlarmHistoryCompanion.insert({
    this.id = const Value.absent(),
    this.alarmId = const Value.absent(),
    required DateTime startedAt,
    this.stoppedAt = const Value.absent(),
    this.result = const Value.absent(),
    this.attempts = const Value.absent(),
    this.snoozeCount = const Value.absent(),
  }) : startedAt = Value(startedAt);
  static Insertable<AlarmHistoryData> custom({
    Expression<int>? id,
    Expression<int>? alarmId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? stoppedAt,
    Expression<String>? result,
    Expression<int>? attempts,
    Expression<int>? snoozeCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alarmId != null) 'alarm_id': alarmId,
      if (startedAt != null) 'started_at': startedAt,
      if (stoppedAt != null) 'stopped_at': stoppedAt,
      if (result != null) 'result': result,
      if (attempts != null) 'attempts': attempts,
      if (snoozeCount != null) 'snooze_count': snoozeCount,
    });
  }

  AlarmHistoryCompanion copyWith({
    Value<int>? id,
    Value<int?>? alarmId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? stoppedAt,
    Value<String>? result,
    Value<int>? attempts,
    Value<int>? snoozeCount,
  }) {
    return AlarmHistoryCompanion(
      id: id ?? this.id,
      alarmId: alarmId ?? this.alarmId,
      startedAt: startedAt ?? this.startedAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      result: result ?? this.result,
      attempts: attempts ?? this.attempts,
      snoozeCount: snoozeCount ?? this.snoozeCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (alarmId.present) {
      map['alarm_id'] = Variable<int>(alarmId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (stoppedAt.present) {
      map['stopped_at'] = Variable<DateTime>(stoppedAt.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (snoozeCount.present) {
      map['snooze_count'] = Variable<int>(snoozeCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlarmHistoryCompanion(')
          ..write('id: $id, ')
          ..write('alarmId: $alarmId, ')
          ..write('startedAt: $startedAt, ')
          ..write('stoppedAt: $stoppedAt, ')
          ..write('result: $result, ')
          ..write('attempts: $attempts, ')
          ..write('snoozeCount: $snoozeCount')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _strictModeDefaultMeta = const VerificationMeta(
    'strictModeDefault',
  );
  @override
  late final GeneratedColumn<bool> strictModeDefault = GeneratedColumn<bool>(
    'strict_mode_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("strict_mode_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinEnabledMeta = const VerificationMeta(
    'pinEnabled',
  );
  @override
  late final GeneratedColumn<bool> pinEnabled = GeneratedColumn<bool>(
    'pin_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pin_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _pinHashMeta = const VerificationMeta(
    'pinHash',
  );
  @override
  late final GeneratedColumn<String> pinHash = GeneratedColumn<String>(
    'pin_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultSoundMeta = const VerificationMeta(
    'defaultSound',
  );
  @override
  late final GeneratedColumn<String> defaultSound = GeneratedColumn<String>(
    'default_sound',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultVolumeMeta = const VerificationMeta(
    'defaultVolume',
  );
  @override
  late final GeneratedColumn<int> defaultVolume = GeneratedColumn<int>(
    'default_volume',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(80),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ar'),
  );
  static const VerificationMeta _themeMeta = const VerificationMeta('theme');
  @override
  late final GeneratedColumn<String> theme = GeneratedColumn<String>(
    'theme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    strictModeDefault,
    pinEnabled,
    pinHash,
    defaultSound,
    defaultVolume,
    language,
    theme,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('strict_mode_default')) {
      context.handle(
        _strictModeDefaultMeta,
        strictModeDefault.isAcceptableOrUnknown(
          data['strict_mode_default']!,
          _strictModeDefaultMeta,
        ),
      );
    }
    if (data.containsKey('pin_enabled')) {
      context.handle(
        _pinEnabledMeta,
        pinEnabled.isAcceptableOrUnknown(data['pin_enabled']!, _pinEnabledMeta),
      );
    }
    if (data.containsKey('pin_hash')) {
      context.handle(
        _pinHashMeta,
        pinHash.isAcceptableOrUnknown(data['pin_hash']!, _pinHashMeta),
      );
    }
    if (data.containsKey('default_sound')) {
      context.handle(
        _defaultSoundMeta,
        defaultSound.isAcceptableOrUnknown(
          data['default_sound']!,
          _defaultSoundMeta,
        ),
      );
    }
    if (data.containsKey('default_volume')) {
      context.handle(
        _defaultVolumeMeta,
        defaultVolume.isAcceptableOrUnknown(
          data['default_volume']!,
          _defaultVolumeMeta,
        ),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('theme')) {
      context.handle(
        _themeMeta,
        theme.isAcceptableOrUnknown(data['theme']!, _themeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      strictModeDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}strict_mode_default'],
      )!,
      pinEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pin_enabled'],
      )!,
      pinHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pin_hash'],
      ),
      defaultSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_sound'],
      ),
      defaultVolume: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_volume'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      theme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final int id;
  final bool strictModeDefault;
  final bool pinEnabled;
  final String? pinHash;
  final String? defaultSound;
  final int defaultVolume;
  final String language;
  final String theme;
  const AppSetting({
    required this.id,
    required this.strictModeDefault,
    required this.pinEnabled,
    this.pinHash,
    this.defaultSound,
    required this.defaultVolume,
    required this.language,
    required this.theme,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['strict_mode_default'] = Variable<bool>(strictModeDefault);
    map['pin_enabled'] = Variable<bool>(pinEnabled);
    if (!nullToAbsent || pinHash != null) {
      map['pin_hash'] = Variable<String>(pinHash);
    }
    if (!nullToAbsent || defaultSound != null) {
      map['default_sound'] = Variable<String>(defaultSound);
    }
    map['default_volume'] = Variable<int>(defaultVolume);
    map['language'] = Variable<String>(language);
    map['theme'] = Variable<String>(theme);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      id: Value(id),
      strictModeDefault: Value(strictModeDefault),
      pinEnabled: Value(pinEnabled),
      pinHash: pinHash == null && nullToAbsent
          ? const Value.absent()
          : Value(pinHash),
      defaultSound: defaultSound == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultSound),
      defaultVolume: Value(defaultVolume),
      language: Value(language),
      theme: Value(theme),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      id: serializer.fromJson<int>(json['id']),
      strictModeDefault: serializer.fromJson<bool>(json['strictModeDefault']),
      pinEnabled: serializer.fromJson<bool>(json['pinEnabled']),
      pinHash: serializer.fromJson<String?>(json['pinHash']),
      defaultSound: serializer.fromJson<String?>(json['defaultSound']),
      defaultVolume: serializer.fromJson<int>(json['defaultVolume']),
      language: serializer.fromJson<String>(json['language']),
      theme: serializer.fromJson<String>(json['theme']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'strictModeDefault': serializer.toJson<bool>(strictModeDefault),
      'pinEnabled': serializer.toJson<bool>(pinEnabled),
      'pinHash': serializer.toJson<String?>(pinHash),
      'defaultSound': serializer.toJson<String?>(defaultSound),
      'defaultVolume': serializer.toJson<int>(defaultVolume),
      'language': serializer.toJson<String>(language),
      'theme': serializer.toJson<String>(theme),
    };
  }

  AppSetting copyWith({
    int? id,
    bool? strictModeDefault,
    bool? pinEnabled,
    Value<String?> pinHash = const Value.absent(),
    Value<String?> defaultSound = const Value.absent(),
    int? defaultVolume,
    String? language,
    String? theme,
  }) => AppSetting(
    id: id ?? this.id,
    strictModeDefault: strictModeDefault ?? this.strictModeDefault,
    pinEnabled: pinEnabled ?? this.pinEnabled,
    pinHash: pinHash.present ? pinHash.value : this.pinHash,
    defaultSound: defaultSound.present ? defaultSound.value : this.defaultSound,
    defaultVolume: defaultVolume ?? this.defaultVolume,
    language: language ?? this.language,
    theme: theme ?? this.theme,
  );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      id: data.id.present ? data.id.value : this.id,
      strictModeDefault: data.strictModeDefault.present
          ? data.strictModeDefault.value
          : this.strictModeDefault,
      pinEnabled: data.pinEnabled.present
          ? data.pinEnabled.value
          : this.pinEnabled,
      pinHash: data.pinHash.present ? data.pinHash.value : this.pinHash,
      defaultSound: data.defaultSound.present
          ? data.defaultSound.value
          : this.defaultSound,
      defaultVolume: data.defaultVolume.present
          ? data.defaultVolume.value
          : this.defaultVolume,
      language: data.language.present ? data.language.value : this.language,
      theme: data.theme.present ? data.theme.value : this.theme,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('id: $id, ')
          ..write('strictModeDefault: $strictModeDefault, ')
          ..write('pinEnabled: $pinEnabled, ')
          ..write('pinHash: $pinHash, ')
          ..write('defaultSound: $defaultSound, ')
          ..write('defaultVolume: $defaultVolume, ')
          ..write('language: $language, ')
          ..write('theme: $theme')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    strictModeDefault,
    pinEnabled,
    pinHash,
    defaultSound,
    defaultVolume,
    language,
    theme,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.id == this.id &&
          other.strictModeDefault == this.strictModeDefault &&
          other.pinEnabled == this.pinEnabled &&
          other.pinHash == this.pinHash &&
          other.defaultSound == this.defaultSound &&
          other.defaultVolume == this.defaultVolume &&
          other.language == this.language &&
          other.theme == this.theme);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<int> id;
  final Value<bool> strictModeDefault;
  final Value<bool> pinEnabled;
  final Value<String?> pinHash;
  final Value<String?> defaultSound;
  final Value<int> defaultVolume;
  final Value<String> language;
  final Value<String> theme;
  const AppSettingsCompanion({
    this.id = const Value.absent(),
    this.strictModeDefault = const Value.absent(),
    this.pinEnabled = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.defaultSound = const Value.absent(),
    this.defaultVolume = const Value.absent(),
    this.language = const Value.absent(),
    this.theme = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.strictModeDefault = const Value.absent(),
    this.pinEnabled = const Value.absent(),
    this.pinHash = const Value.absent(),
    this.defaultSound = const Value.absent(),
    this.defaultVolume = const Value.absent(),
    this.language = const Value.absent(),
    this.theme = const Value.absent(),
  });
  static Insertable<AppSetting> custom({
    Expression<int>? id,
    Expression<bool>? strictModeDefault,
    Expression<bool>? pinEnabled,
    Expression<String>? pinHash,
    Expression<String>? defaultSound,
    Expression<int>? defaultVolume,
    Expression<String>? language,
    Expression<String>? theme,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (strictModeDefault != null) 'strict_mode_default': strictModeDefault,
      if (pinEnabled != null) 'pin_enabled': pinEnabled,
      if (pinHash != null) 'pin_hash': pinHash,
      if (defaultSound != null) 'default_sound': defaultSound,
      if (defaultVolume != null) 'default_volume': defaultVolume,
      if (language != null) 'language': language,
      if (theme != null) 'theme': theme,
    });
  }

  AppSettingsCompanion copyWith({
    Value<int>? id,
    Value<bool>? strictModeDefault,
    Value<bool>? pinEnabled,
    Value<String?>? pinHash,
    Value<String?>? defaultSound,
    Value<int>? defaultVolume,
    Value<String>? language,
    Value<String>? theme,
  }) {
    return AppSettingsCompanion(
      id: id ?? this.id,
      strictModeDefault: strictModeDefault ?? this.strictModeDefault,
      pinEnabled: pinEnabled ?? this.pinEnabled,
      pinHash: pinHash ?? this.pinHash,
      defaultSound: defaultSound ?? this.defaultSound,
      defaultVolume: defaultVolume ?? this.defaultVolume,
      language: language ?? this.language,
      theme: theme ?? this.theme,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (strictModeDefault.present) {
      map['strict_mode_default'] = Variable<bool>(strictModeDefault.value);
    }
    if (pinEnabled.present) {
      map['pin_enabled'] = Variable<bool>(pinEnabled.value);
    }
    if (pinHash.present) {
      map['pin_hash'] = Variable<String>(pinHash.value);
    }
    if (defaultSound.present) {
      map['default_sound'] = Variable<String>(defaultSound.value);
    }
    if (defaultVolume.present) {
      map['default_volume'] = Variable<int>(defaultVolume.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (theme.present) {
      map['theme'] = Variable<String>(theme.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('id: $id, ')
          ..write('strictModeDefault: $strictModeDefault, ')
          ..write('pinEnabled: $pinEnabled, ')
          ..write('pinHash: $pinHash, ')
          ..write('defaultSound: $defaultSound, ')
          ..write('defaultVolume: $defaultVolume, ')
          ..write('language: $language, ')
          ..write('theme: $theme')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AlarmsTable alarms = $AlarmsTable(this);
  late final $MissionsTable missions = $MissionsTable(this);
  late final $AlarmHistoryTable alarmHistory = $AlarmHistoryTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final AlarmDao alarmDao = AlarmDao(this as AppDatabase);
  late final MissionDao missionDao = MissionDao(this as AppDatabase);
  late final AlarmHistoryDao alarmHistoryDao = AlarmHistoryDao(
    this as AppDatabase,
  );
  late final AppSettingsDao appSettingsDao = AppSettingsDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    alarms,
    missions,
    alarmHistory,
    appSettings,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'alarms',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('missions', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AlarmsTableCreateCompanionBuilder = AlarmsCompanion Function({
  Value<int> id,
  Value<String?> label,
  required int hour,
  required int minute,
  Value<bool> enabled,
  Value<String> repeatType,
  Value<int?> repeatDays,
  Value<DateTime?> onceDate,
  Value<String?> soundUri,
  Value<String> soundType,
  Value<int> volume,
  Value<bool> fadeInEnabled,
  Value<bool> vibrationEnabled,
  Value<bool> snoozeEnabled,
  Value<int> snoozeMinutes,
  Value<int> snoozeMaxCount,
  Value<bool> strictMode,
  Value<DateTime?> nextTriggerAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});
typedef $$AlarmsTableUpdateCompanionBuilder = AlarmsCompanion Function({
  Value<int> id,
  Value<String?> label,
  Value<int> hour,
  Value<int> minute,
  Value<bool> enabled,
  Value<String> repeatType,
  Value<int?> repeatDays,
  Value<DateTime?> onceDate,
  Value<String?> soundUri,
  Value<String> soundType,
  Value<int> volume,
  Value<bool> fadeInEnabled,
  Value<bool> vibrationEnabled,
  Value<bool> snoozeEnabled,
  Value<int> snoozeMinutes,
  Value<int> snoozeMaxCount,
  Value<bool> strictMode,
  Value<DateTime?> nextTriggerAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$AlarmsTableReferences
    extends BaseReferences<_$AppDatabase, $AlarmsTable, Alarm> {
  $$AlarmsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MissionsTable, List<Mission>> _missionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.missions,
    aliasName: 'alarms__id__missions__alarm_id',
  );

  $$MissionsTableProcessedTableManager get missionsRefs {
    final manager = $$MissionsTableTableManager(
      $_db,
      $_db.missions,
    ).filter((f) => f.alarmId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_missionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AlarmsTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmsTable> {
  $$AlarmsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get onceDate => $composableBuilder(
    column: $table.onceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get soundUri => $composableBuilder(
    column: $table.soundUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get soundType => $composableBuilder(
    column: $table.soundType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fadeInEnabled => $composableBuilder(
    column: $table.fadeInEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vibrationEnabled => $composableBuilder(
    column: $table.vibrationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get snoozeEnabled => $composableBuilder(
    column: $table.snoozeEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeMaxCount => $composableBuilder(
    column: $table.snoozeMaxCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get strictMode => $composableBuilder(
    column: $table.strictMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextTriggerAt => $composableBuilder(
    column: $table.nextTriggerAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> missionsRefs(
    Expression<bool> Function($$MissionsTableFilterComposer f) f,
  ) {
    final $$MissionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.alarmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableFilterComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlarmsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmsTable> {
  $$AlarmsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hour => $composableBuilder(
    column: $table.hour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minute => $composableBuilder(
    column: $table.minute,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get onceDate => $composableBuilder(
    column: $table.onceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get soundUri => $composableBuilder(
    column: $table.soundUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get soundType => $composableBuilder(
    column: $table.soundType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get volume => $composableBuilder(
    column: $table.volume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fadeInEnabled => $composableBuilder(
    column: $table.fadeInEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vibrationEnabled => $composableBuilder(
    column: $table.vibrationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get snoozeEnabled => $composableBuilder(
    column: $table.snoozeEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeMaxCount => $composableBuilder(
    column: $table.snoozeMaxCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get strictMode => $composableBuilder(
    column: $table.strictMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextTriggerAt => $composableBuilder(
    column: $table.nextTriggerAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlarmsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmsTable> {
  $$AlarmsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get repeatType => $composableBuilder(
    column: $table.repeatType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repeatDays => $composableBuilder(
    column: $table.repeatDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get onceDate =>
      $composableBuilder(column: $table.onceDate, builder: (column) => column);

  GeneratedColumn<String> get soundUri =>
      $composableBuilder(column: $table.soundUri, builder: (column) => column);

  GeneratedColumn<String> get soundType =>
      $composableBuilder(column: $table.soundType, builder: (column) => column);

  GeneratedColumn<int> get volume =>
      $composableBuilder(column: $table.volume, builder: (column) => column);

  GeneratedColumn<bool> get fadeInEnabled => $composableBuilder(
    column: $table.fadeInEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get vibrationEnabled => $composableBuilder(
    column: $table.vibrationEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get snoozeEnabled => $composableBuilder(
    column: $table.snoozeEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeMinutes => $composableBuilder(
    column: $table.snoozeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeMaxCount => $composableBuilder(
    column: $table.snoozeMaxCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get strictMode => $composableBuilder(
    column: $table.strictMode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextTriggerAt => $composableBuilder(
    column: $table.nextTriggerAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> missionsRefs<T extends Object>(
    Expression<T> Function($$MissionsTableAnnotationComposer a) f,
  ) {
    final $$MissionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.missions,
      getReferencedColumn: (t) => t.alarmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MissionsTableAnnotationComposer(
            $db: $db,
            $table: $db.missions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AlarmsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmsTable,
          Alarm,
          $$AlarmsTableFilterComposer,
          $$AlarmsTableOrderingComposer,
          $$AlarmsTableAnnotationComposer,
          $$AlarmsTableCreateCompanionBuilder,
          $$AlarmsTableUpdateCompanionBuilder,
          (Alarm, $$AlarmsTableReferences),
          Alarm,
          PrefetchHooks Function({bool missionsRefs})
        > {
  $$AlarmsTableTableManager(_$AppDatabase db, $AlarmsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> minute = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> repeatType = const Value.absent(),
                Value<int?> repeatDays = const Value.absent(),
                Value<DateTime?> onceDate = const Value.absent(),
                Value<String?> soundUri = const Value.absent(),
                Value<String> soundType = const Value.absent(),
                Value<int> volume = const Value.absent(),
                Value<bool> fadeInEnabled = const Value.absent(),
                Value<bool> vibrationEnabled = const Value.absent(),
                Value<bool> snoozeEnabled = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<int> snoozeMaxCount = const Value.absent(),
                Value<bool> strictMode = const Value.absent(),
                Value<DateTime?> nextTriggerAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AlarmsCompanion(
                id: id,
                label: label,
                hour: hour,
                minute: minute,
                enabled: enabled,
                repeatType: repeatType,
                repeatDays: repeatDays,
                onceDate: onceDate,
                soundUri: soundUri,
                soundType: soundType,
                volume: volume,
                fadeInEnabled: fadeInEnabled,
                vibrationEnabled: vibrationEnabled,
                snoozeEnabled: snoozeEnabled,
                snoozeMinutes: snoozeMinutes,
                snoozeMaxCount: snoozeMaxCount,
                strictMode: strictMode,
                nextTriggerAt: nextTriggerAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> label = const Value.absent(),
                required int hour,
                required int minute,
                Value<bool> enabled = const Value.absent(),
                Value<String> repeatType = const Value.absent(),
                Value<int?> repeatDays = const Value.absent(),
                Value<DateTime?> onceDate = const Value.absent(),
                Value<String?> soundUri = const Value.absent(),
                Value<String> soundType = const Value.absent(),
                Value<int> volume = const Value.absent(),
                Value<bool> fadeInEnabled = const Value.absent(),
                Value<bool> vibrationEnabled = const Value.absent(),
                Value<bool> snoozeEnabled = const Value.absent(),
                Value<int> snoozeMinutes = const Value.absent(),
                Value<int> snoozeMaxCount = const Value.absent(),
                Value<bool> strictMode = const Value.absent(),
                Value<DateTime?> nextTriggerAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => AlarmsCompanion.insert(
                id: id,
                label: label,
                hour: hour,
                minute: minute,
                enabled: enabled,
                repeatType: repeatType,
                repeatDays: repeatDays,
                onceDate: onceDate,
                soundUri: soundUri,
                soundType: soundType,
                volume: volume,
                fadeInEnabled: fadeInEnabled,
                vibrationEnabled: vibrationEnabled,
                snoozeEnabled: snoozeEnabled,
                snoozeMinutes: snoozeMinutes,
                snoozeMaxCount: snoozeMaxCount,
                strictMode: strictMode,
                nextTriggerAt: nextTriggerAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AlarmsTable, Alarm>(table),
                  $$AlarmsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({missionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (missionsRefs) db.missions],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (missionsRefs)
                    await $_getPrefetchedData<Alarm, $AlarmsTable, Mission>(
                      currentTable: table,
                      referencedTable: $$AlarmsTableReferences
                          ._missionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$AlarmsTableReferences(db, table, p0).missionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.alarmId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$AlarmsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmsTable,
      Alarm,
      $$AlarmsTableFilterComposer,
      $$AlarmsTableOrderingComposer,
      $$AlarmsTableAnnotationComposer,
      $$AlarmsTableCreateCompanionBuilder,
      $$AlarmsTableUpdateCompanionBuilder,
      (Alarm, $$AlarmsTableReferences),
      Alarm,
      PrefetchHooks Function({bool missionsRefs})
    >;
typedef $$MissionsTableCreateCompanionBuilder = MissionsCompanion Function({
  Value<int> id,
  required int alarmId,
  required String type,
  Value<int> orderIndex,
  Value<String?> configJson,
  Value<bool> required,
});
typedef $$MissionsTableUpdateCompanionBuilder = MissionsCompanion Function({
  Value<int> id,
  Value<int> alarmId,
  Value<String> type,
  Value<int> orderIndex,
  Value<String?> configJson,
  Value<bool> required,
});

final class $$MissionsTableReferences
    extends BaseReferences<_$AppDatabase, $MissionsTable, Mission> {
  $$MissionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AlarmsTable _alarmIdTable(_$AppDatabase db) =>
      db.alarms.createAlias('missions__alarm_id__alarms__id');

  $$AlarmsTableProcessedTableManager get alarmId {
    final $_column = $_itemColumn<int>('alarm_id')!;

    final manager = $$AlarmsTableTableManager(
      $_db,
      $_db.alarms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_alarmIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MissionsTableFilterComposer
    extends Composer<_$AppDatabase, $MissionsTable> {
  $$MissionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get required => $composableBuilder(
    column: $table.required,
    builder: (column) => ColumnFilters(column),
  );

  $$AlarmsTableFilterComposer get alarmId {
    final $$AlarmsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alarmId,
      referencedTable: $db.alarms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlarmsTableFilterComposer(
            $db: $db,
            $table: $db.alarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissionsTableOrderingComposer
    extends Composer<_$AppDatabase, $MissionsTable> {
  $$MissionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get required => $composableBuilder(
    column: $table.required,
    builder: (column) => ColumnOrderings(column),
  );

  $$AlarmsTableOrderingComposer get alarmId {
    final $$AlarmsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alarmId,
      referencedTable: $db.alarms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlarmsTableOrderingComposer(
            $db: $db,
            $table: $db.alarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MissionsTable> {
  $$MissionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get required =>
      $composableBuilder(column: $table.required, builder: (column) => column);

  $$AlarmsTableAnnotationComposer get alarmId {
    final $$AlarmsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.alarmId,
      referencedTable: $db.alarms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlarmsTableAnnotationComposer(
            $db: $db,
            $table: $db.alarms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MissionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MissionsTable,
          Mission,
          $$MissionsTableFilterComposer,
          $$MissionsTableOrderingComposer,
          $$MissionsTableAnnotationComposer,
          $$MissionsTableCreateCompanionBuilder,
          $$MissionsTableUpdateCompanionBuilder,
          (Mission, $$MissionsTableReferences),
          Mission,
          PrefetchHooks Function({bool alarmId})
        > {
  $$MissionsTableTableManager(_$AppDatabase db, $MissionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MissionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MissionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MissionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> alarmId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<bool> required = const Value.absent(),
              }) => MissionsCompanion(
                id: id,
                alarmId: alarmId,
                type: type,
                orderIndex: orderIndex,
                configJson: configJson,
                required: required,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int alarmId,
                required String type,
                Value<int> orderIndex = const Value.absent(),
                Value<String?> configJson = const Value.absent(),
                Value<bool> required = const Value.absent(),
              }) => MissionsCompanion.insert(
                id: id,
                alarmId: alarmId,
                type: type,
                orderIndex: orderIndex,
                configJson: configJson,
                required: required,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MissionsTable, Mission>(table),
                  $$MissionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({alarmId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (alarmId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.alarmId,
                        referencedTable: $$MissionsTableReferences
                            ._alarmIdTable(db),
                        referencedColumn: $$MissionsTableReferences
                            ._alarmIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MissionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MissionsTable,
      Mission,
      $$MissionsTableFilterComposer,
      $$MissionsTableOrderingComposer,
      $$MissionsTableAnnotationComposer,
      $$MissionsTableCreateCompanionBuilder,
      $$MissionsTableUpdateCompanionBuilder,
      (Mission, $$MissionsTableReferences),
      Mission,
      PrefetchHooks Function({bool alarmId})
    >;
typedef $$AlarmHistoryTableCreateCompanionBuilder =
    AlarmHistoryCompanion Function({
      Value<int> id,
      Value<int?> alarmId,
      required DateTime startedAt,
      Value<DateTime?> stoppedAt,
      Value<String> result,
      Value<int> attempts,
      Value<int> snoozeCount,
    });
typedef $$AlarmHistoryTableUpdateCompanionBuilder =
    AlarmHistoryCompanion Function({
      Value<int> id,
      Value<int?> alarmId,
      Value<DateTime> startedAt,
      Value<DateTime?> stoppedAt,
      Value<String> result,
      Value<int> attempts,
      Value<int> snoozeCount,
    });

class $$AlarmHistoryTableFilterComposer
    extends Composer<_$AppDatabase, $AlarmHistoryTable> {
  $$AlarmHistoryTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get stoppedAt => $composableBuilder(
    column: $table.stoppedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AlarmHistoryTableOrderingComposer
    extends Composer<_$AppDatabase, $AlarmHistoryTable> {
  $$AlarmHistoryTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get alarmId => $composableBuilder(
    column: $table.alarmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get stoppedAt => $composableBuilder(
    column: $table.stoppedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AlarmHistoryTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlarmHistoryTable> {
  $$AlarmHistoryTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get alarmId =>
      $composableBuilder(column: $table.alarmId, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get stoppedAt =>
      $composableBuilder(column: $table.stoppedAt, builder: (column) => column);

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => column,
  );
}

class $$AlarmHistoryTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlarmHistoryTable,
          AlarmHistoryData,
          $$AlarmHistoryTableFilterComposer,
          $$AlarmHistoryTableOrderingComposer,
          $$AlarmHistoryTableAnnotationComposer,
          $$AlarmHistoryTableCreateCompanionBuilder,
          $$AlarmHistoryTableUpdateCompanionBuilder,
          (
            AlarmHistoryData,
            BaseReferences<_$AppDatabase, $AlarmHistoryTable, AlarmHistoryData>,
          ),
          AlarmHistoryData,
          PrefetchHooks Function()
        > {
  $$AlarmHistoryTableTableManager(_$AppDatabase db, $AlarmHistoryTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlarmHistoryTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlarmHistoryTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlarmHistoryTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> alarmId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> stoppedAt = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
              }) => AlarmHistoryCompanion(
                id: id,
                alarmId: alarmId,
                startedAt: startedAt,
                stoppedAt: stoppedAt,
                result: result,
                attempts: attempts,
                snoozeCount: snoozeCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> alarmId = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> stoppedAt = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
              }) => AlarmHistoryCompanion.insert(
                id: id,
                alarmId: alarmId,
                startedAt: startedAt,
                stoppedAt: stoppedAt,
                result: result,
                attempts: attempts,
                snoozeCount: snoozeCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AlarmHistoryTable, AlarmHistoryData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AlarmHistoryTable,
                    AlarmHistoryData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AlarmHistoryTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlarmHistoryTable,
      AlarmHistoryData,
      $$AlarmHistoryTableFilterComposer,
      $$AlarmHistoryTableOrderingComposer,
      $$AlarmHistoryTableAnnotationComposer,
      $$AlarmHistoryTableCreateCompanionBuilder,
      $$AlarmHistoryTableUpdateCompanionBuilder,
      (
        AlarmHistoryData,
        BaseReferences<_$AppDatabase, $AlarmHistoryTable, AlarmHistoryData>,
      ),
      AlarmHistoryData,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<bool> strictModeDefault,
      Value<bool> pinEnabled,
      Value<String?> pinHash,
      Value<String?> defaultSound,
      Value<int> defaultVolume,
      Value<String> language,
      Value<String> theme,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<int> id,
      Value<bool> strictModeDefault,
      Value<bool> pinEnabled,
      Value<String?> pinHash,
      Value<String?> defaultSound,
      Value<int> defaultVolume,
      Value<String> language,
      Value<String> theme,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get strictModeDefault => $composableBuilder(
    column: $table.strictModeDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pinEnabled => $composableBuilder(
    column: $table.pinEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultSound => $composableBuilder(
    column: $table.defaultSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultVolume => $composableBuilder(
    column: $table.defaultVolume,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get strictModeDefault => $composableBuilder(
    column: $table.strictModeDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pinEnabled => $composableBuilder(
    column: $table.pinEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pinHash => $composableBuilder(
    column: $table.pinHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultSound => $composableBuilder(
    column: $table.defaultSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultVolume => $composableBuilder(
    column: $table.defaultVolume,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get theme => $composableBuilder(
    column: $table.theme,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get strictModeDefault => $composableBuilder(
    column: $table.strictModeDefault,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pinEnabled => $composableBuilder(
    column: $table.pinEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pinHash =>
      $composableBuilder(column: $table.pinHash, builder: (column) => column);

  GeneratedColumn<String> get defaultSound => $composableBuilder(
    column: $table.defaultSound,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultVolume => $composableBuilder(
    column: $table.defaultVolume,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get theme =>
      $composableBuilder(column: $table.theme, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> strictModeDefault = const Value.absent(),
                Value<bool> pinEnabled = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<String?> defaultSound = const Value.absent(),
                Value<int> defaultVolume = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> theme = const Value.absent(),
              }) => AppSettingsCompanion(
                id: id,
                strictModeDefault: strictModeDefault,
                pinEnabled: pinEnabled,
                pinHash: pinHash,
                defaultSound: defaultSound,
                defaultVolume: defaultVolume,
                language: language,
                theme: theme,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> strictModeDefault = const Value.absent(),
                Value<bool> pinEnabled = const Value.absent(),
                Value<String?> pinHash = const Value.absent(),
                Value<String?> defaultSound = const Value.absent(),
                Value<int> defaultVolume = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String> theme = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                id: id,
                strictModeDefault: strictModeDefault,
                pinEnabled: pinEnabled,
                pinHash: pinHash,
                defaultSound: defaultSound,
                defaultVolume: defaultVolume,
                language: language,
                theme: theme,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AlarmsTableTableManager get alarms =>
      $$AlarmsTableTableManager(_db, _db.alarms);
  $$MissionsTableTableManager get missions =>
      $$MissionsTableTableManager(_db, _db.missions);
  $$AlarmHistoryTableTableManager get alarmHistory =>
      $$AlarmHistoryTableTableManager(_db, _db.alarmHistory);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
