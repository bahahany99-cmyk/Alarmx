import 'package:alarmx/core/models/alarm_result.dart';
import 'package:alarmx/core/models/mission_type.dart';
import 'package:alarmx/core/models/repeat_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RepeatType', () {
    test('stored strings are exact', () {
      expect(RepeatType.once.dbValue, 'once');
      expect(RepeatType.daily.dbValue, 'daily');
      expect(RepeatType.custom.dbValue, 'custom');
    });

    test('every value round-trips through the database string', () {
      for (final RepeatType type in RepeatType.values) {
        expect(RepeatType.fromDbValue(type.dbValue), type);
      }
    });

    test('unknown values fall back to once', () {
      expect(RepeatType.fromDbValue('weekly'), RepeatType.once);
      expect(RepeatType.fromDbValue(''), RepeatType.once);
    });
  });

  group('MissionType', () {
    test('stored strings are exact', () {
      expect(MissionType.none.dbValue, 'none');
      expect(MissionType.math.dbValue, 'math');
      expect(MissionType.qr.dbValue, 'qr');
      expect(MissionType.barcode.dbValue, 'barcode');
      expect(MissionType.photo.dbValue, 'photo');
      expect(MissionType.typing.dbValue, 'typing');
      expect(MissionType.shake.dbValue, 'shake');
    });

    test('every value round-trips through the database string', () {
      for (final MissionType type in MissionType.values) {
        expect(MissionType.fromDbValue(type.dbValue), type);
      }
    });

    test('unknown values fall back to none', () {
      expect(MissionType.fromDbValue('nfc'), MissionType.none);
      expect(MissionType.fromDbValue(''), MissionType.none);
    });
  });

  group('AlarmResult', () {
    test('stored strings are exact', () {
      expect(AlarmResult.ongoing.dbValue, 'ongoing');
      expect(AlarmResult.success.dbValue, 'success');
      expect(AlarmResult.emergencyStop.dbValue, 'emergency_stop');
      expect(AlarmResult.failed.dbValue, 'failed');
    });

    test('every value round-trips through the database string', () {
      for (final AlarmResult result in AlarmResult.values) {
        expect(AlarmResult.fromDbValue(result.dbValue), result);
      }
    });

    test('unknown values fall back to ongoing', () {
      expect(AlarmResult.fromDbValue('snoozed'), AlarmResult.ongoing);
      expect(AlarmResult.fromDbValue(''), AlarmResult.ongoing);
    });
  });
}
