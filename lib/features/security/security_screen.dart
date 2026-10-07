// Security settings screen (Phase 5).
//
// PIN management (enable / change / disable, each authenticated as
// appropriate) plus the Strict Mode default for new alarms. Reached
// from the Home menu; the only settings surface the app has, so PIN
// configuration lives here rather than in a second settings system.
//
// All PIN entry is obscured; failures report inline (dialogs) or via
// SnackBar (disable flow) without ever echoing PIN content.

import 'package:alarmx/core/database/database.dart';
import 'package:alarmx/core/l10n/app_strings.dart';
import 'package:alarmx/core/repositories/app_settings_repository.dart';
import 'package:alarmx/core/security/pin_service.dart';
import 'package:alarmx/features/security/pin_prompt.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

/// PIN + Strict-default settings; see the file docs.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({
    super.key,
    required this.settings,
    required this.pinService,
  });

  final AppSettingsRepository settings;
  final PinService pinService;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _loading = true;
  bool _loadFailed = false;
  bool _pinEnabled = false;
  bool _strictDefault = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    final bool enabled;
    final bool strictDefault;
    try {
      enabled = await widget.pinService.isPinEnabled();
      strictDefault =
          (await widget.settings.getSettings()).strictModeDefault;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pinEnabled = enabled;
      _strictDefault = strictDefault;
      _loading = false;
    });
  }

  Future<void> _toggleStrictDefault(bool value) async {
    setState(() {
      _strictDefault = value;
    });
    try {
      await widget.settings.updateSettings(
        AppSettingsCompanion(strictModeDefault: Value<bool>(value)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _strictDefault = !value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).msgToggleFailed)),
      );
    }
  }

  Future<void> _enablePin() async {
    final bool? done = await showDialog<bool>(
      context: context,
      builder: (_) => PinSetupDialog(
        pinService: widget.pinService,
        requireCurrent: false,
      ),
    );
    if (done == true && mounted) {
      _reload();
    }
  }

  Future<void> _changePin() async {
    final bool? done = await showDialog<bool>(
      context: context,
      builder: (_) => PinSetupDialog(
        pinService: widget.pinService,
        requireCurrent: true,
      ),
    );
    if (done == true && mounted) {
      _reload();
    }
  }

  Future<void> _disablePin() async {
    final AppStrings strings = AppStrings.of(context);
    final String? current = await showPinPrompt(
      context,
      title: strings.pinDisable,
      label: strings.pinCurrent,
    );
    if (current == null || !mounted) {
      return;
    }
    final String? errorKey = await widget.pinService.disablePin(current);
    if (!mounted) {
      return;
    }
    if (errorKey != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.text(errorKey))),
      );
      return;
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.securityTitle)),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadFailed
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            strings.msgLoadFailed,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const Key('security_retry_button'),
                            onPressed: _reload,
                            child: Text(strings.missionRetry),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      Card(
                        child: ListTile(
                          leading: Icon(
                            _pinEnabled ? Icons.lock : Icons.lock_open,
                          ),
                          title: Text(strings.securityTitle),
                          subtitle: Text(
                            _pinEnabled
                                ? strings.pinStatusEnabled
                                : strings.pinStatusDisabled,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!_pinEnabled)
                        FilledButton(
                          key: const Key('security_enable_pin_button'),
                          onPressed: _enablePin,
                          child: Text(strings.pinEnable),
                        )
                      else ...<Widget>[
                        FilledButton(
                          key: const Key('security_change_pin_button'),
                          onPressed: _changePin,
                          child: Text(strings.pinChange),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          key: const Key('security_disable_pin_button'),
                          onPressed: _disablePin,
                          child: Text(strings.pinDisable),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Card(
                        child: SwitchListTile(
                          key: const Key('security_strict_default_switch'),
                          title: Text(strings.strictDefaultLabel),
                          subtitle: Text(strings.strictDefaultCaption),
                          value: _strictDefault,
                          onChanged: _toggleStrictDefault,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// PIN set/change dialog with inline error reporting.
///
/// Calls [PinService.setPin] (or [PinService.changePin] when
/// [requireCurrent]) and pops `true` on success; validation and
/// authentication failures show inline and keep the dialog open.
class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({
    super.key,
    required this.pinService,
    required this.requireCurrent,
  });

  final PinService pinService;
  final bool requireCurrent;

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  String? _errorKey;
  bool _saving = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _errorKey = null;
    });
    final String? errorKey = widget.requireCurrent
        ? await widget.pinService.changePin(
            current: _currentController.text,
            pin: _newController.text,
            confirmation: _confirmController.text,
          )
        : await widget.pinService.setPin(
            pin: _newController.text,
            confirmation: _confirmController.text,
          );
    if (!mounted) {
      return;
    }
    if (errorKey != null) {
      setState(() {
        _saving = false;
        _errorKey = errorKey;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: kPinMaxLength,
        onChanged: (_) {
          if (_errorKey != null) {
            setState(() => _errorKey = null);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.requireCurrent ? strings.pinChange : strings.pinEnable,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.requireCurrent)
              _field(
                key: const Key('pin_setup_current'),
                controller: _currentController,
                label: strings.pinCurrent,
              ),
            _field(
              key: const Key('pin_setup_new'),
              controller: _newController,
              label: strings.pinNew,
            ),
            _field(
              key: const Key('pin_setup_confirm'),
              controller: _confirmController,
              label: strings.pinConfirmNew,
            ),
            if (_errorKey != null)
              Text(
                strings.text(_errorKey!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          key: const Key('pin_setup_save'),
          onPressed: _saving ? null : _save,
          child: Text(strings.pinConfirm),
        ),
      ],
    );
  }
}
