package com.alarmx.app.alarmx

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart -> native alarm-scheduler calls, shared by the UI engine
 * ([MainActivity]) and the headless boot engine ([BootReceiver]) so both
 * paths schedule, cancel, and tokenize identically.
 *
 * Channel name: `"com.alarmx.app.alarmx/alarm_scheduler"`
 * Methods:
 *   - `scheduleExactAlarm`  args: `{ "alarmId": Int, "triggerAtMillis": Long,
 *       plus for persisted alarms "label": String? and "vibrationEnabled": Boolean }`
 *   - `cancelAlarm`         args: `{ "alarmId": Int }`
 *   - `canScheduleExactAlarms`  args: `{}`
 *   - `getRingingLaunch`  args: `{}`: the pending Flutter ring launch
 *     `{alarmId, label?, triggerAtMillis?}`, consumed exactly once, or
 *     null for a normal start.
 *   - `stopRingingAlarm`  args: `{ "alarmId": Int }`: stops the ring
 *     through the service `ACTION_STOP` path (idempotent).
 *   - `getPermissionSnapshot`  args: `{}`: one map with the raw system
 *     states the Permission Center reports (`sdkInt`,
 *     `notificationsEnabled`, `postNotificationsGranted?`,
 *     `ringingChannelEnabled`, `canScheduleExactAlarms`,
 *     `fullScreenIntentAllowed?`, `batteryExempt`,
 *     `bootReceiverEnabled`). Each probe fails soft to null (Dart reads
 *     null as unknown) so one OEM quirk never blanks the snapshot.
 *   - `openSystemSettings`  args: `{ "target": String }`: opens a system
 *     settings page (`notifications`, `exactAlarm`, `fullScreen`,
 *     `battery`, `appDetails`), resolve-checked with an app-details
 *     fallback. Returns whether a page was launched; targets with no
 *     page on the running Android version return false.
 *
 * A schedule call carrying a fire payload (label and/or vibration key
 * present) is a real persisted alarm: its config is frozen into the
 * PendingIntent extras and the schedule is recorded in [AlarmScheduleLedger]
 * so stale deliveries can be dropped on fire. A call with id + trigger only
 * is a legacy test alarm and keeps the exact Phase 1.2 behavior (id extra
 * only, no ledger interaction). Both share the requestCode slot namespace:
 * scheduling either kind for an id replaces whatever was pending for it.
 */
class AlarmSchedulerChannelHandler(
    private val context: Context,
    private val alarmManager: AlarmManager,
) {

    companion object {
        const val CHANNEL_NAME = "com.alarmx.app.alarmx/alarm_scheduler"
    }

    /**
     * Handles one scheduler call, reporting argument problems as
     * `INVALID_ARGS` and unexpected failures as `NATIVE_ERROR`. Unknown
     * methods answer `notImplemented` so hosts can layer their own methods
     * (e.g. the boot completion handshake) around this handler.
     */
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "scheduleExactAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId")
                    val triggerAtMillis = call.argument<Number>("triggerAtMillis")?.toLong()
                    if (alarmId == null || triggerAtMillis == null) {
                        result.error(
                            "INVALID_ARGS",
                            "scheduleExactAlarm requires alarmId (Int) and triggerAtMillis (Long).",
                            null,
                        )
                        return@handle
                    }
                    // Presence of either fire-payload key marks a real
                    // persisted alarm (Dart always sends both together;
                    // accepting either keeps a partial caller on the
                    // verifying path with defaults).
                    val isPersisted = call.hasArgument("label") ||
                        call.hasArgument("vibrationEnabled")
                    val fireLabel = call.argument<String>("label")
                    val fireVibration =
                        call.argument<Boolean>("vibrationEnabled") ?: true
                    scheduleExact(
                        alarmId,
                        triggerAtMillis,
                        fireLabel,
                        fireVibration,
                        isPersisted,
                    )
                    result.success(null)
                }

                "cancelAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId")
                    if (alarmId == null) {
                        result.error(
                            "INVALID_ARGS",
                            "cancelAlarm requires alarmId (Int).",
                            null,
                        )
                        return@handle
                    }
                    cancelExact(alarmId)
                    result.success(null)
                }

                "canScheduleExactAlarms" -> {
                    val can = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        alarmManager.canScheduleExactAlarms()
                    } else {
                        true
                    }
                    result.success(can)
                }

                "getRingingLaunch" -> {
                    result.success(MainActivity.consumeRingingLaunch())
                }

                "stopRingingAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId")
                    if (alarmId == null) {
                        result.error(
                            "INVALID_ARGS",
                            "stopRingingAlarm requires alarmId (Int).",
                            null,
                        )
                        return@handle
                    }
                    try {
                        context.startService(
                            Intent(context, AlarmForegroundService::class.java).apply {
                                action = AlarmForegroundService.ACTION_STOP
                            },
                        )
                    } catch (t: Throwable) {
                        Log.w("AlarmX", "stopRingingAlarm failed for id: $alarmId.", t)
                        result.error("NATIVE_ERROR", t.message, null)
                        return@handle
                    }
                    Log.d("AlarmX", "Stop sent to ringing service for id: $alarmId.")
                    result.success(null)
                }

                "getPermissionSnapshot" -> {
                    result.success(buildPermissionSnapshot())
                }

                "openSystemSettings" -> {
                    val target = call.argument<String>("target")
                    if (target == null) {
                        result.error(
                            "INVALID_ARGS",
                            "openSystemSettings requires target (String).",
                            null,
                        )
                        return@handle
                    }
                    result.success(openSettingsTarget(target))
                }

                else -> result.notImplemented()
            }
        } catch (t: Throwable) {
            result.error("NATIVE_ERROR", t.message, null)
        }
    }

    /**
     * Schedules a one-shot exact alarm. The PendingIntent's request code is
     * the alarmId itself so different alarms never collide; this also lets
     * [cancelExact] find the right PendingIntent to cancel.
     *
     * When [isPersisted] is true the fire config is frozen into the
     * PendingIntent and the schedule is recorded in [AlarmScheduleLedger]
     * BEFORE the AlarmManager call (see the ledger ordering contract).
     */
    private fun scheduleExact(
        alarmId: Int,
        triggerAtMillis: Long,
        fireLabel: String?,
        fireVibration: Boolean,
        isPersisted: Boolean,
    ) {
        if (isPersisted) {
            AlarmScheduleLedger.putScheduled(context, alarmId, triggerAtMillis)
        }
        val pendingIntent = buildAlarmPendingIntent(
            alarmId,
            triggerAtMillis,
            fireLabel,
            fireVibration,
            isPersisted,
        )
        alarmManager.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pendingIntent,
        )
    }

    /**
     * Cancels the alarm previously scheduled for [alarmId]. The PendingIntent
     * built here must be equivalent to the one used in [scheduleExact] (same
     * request code + same intent component/action/extras); we reuse the
     * single helper to guarantee that. (Intent extras do not affect
     * PendingIntent matching, so this id-only form also cancels persisted
     * schedules that carry a fire payload.)
     *
     * If the alarm already fired and [AlarmForegroundService] is ringing, the
     * service is stopped as well so "cancel" reliably silences the alarm. This
     * is a no-op when the service is not running.
     */
    private fun cancelExact(alarmId: Int) {
        alarmManager.cancel(buildAlarmPendingIntent(alarmId))
        // AFTER the AlarmManager cancel (see the ledger ordering contract);
        // a no-op for legacy test ids the ledger never recorded.
        AlarmScheduleLedger.removeScheduled(context, alarmId)
        try {
            context.stopService(Intent(context, AlarmForegroundService::class.java))
        } catch (t: Throwable) {
            Log.w("AlarmX", "Could not stop ringing service during cancel.", t)
        }
    }

    /**
     * Reads the raw system states for the Permission Center snapshot. Every
     * probe fails soft to null so a single OEM quirk degrades one
     * capability to unknown instead of failing the whole call. No state is
     * ever requested or changed here: this only reports what Android
     * currently allows.
     */
    private fun buildPermissionSnapshot(): Map<String, Any?> {
        val sdkInt = Build.VERSION.SDK_INT
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val powerManager =
            context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val notificationsEnabled: Boolean? = runCatching {
            notificationManager.areNotificationsEnabled()
        }.getOrNull()
        // Runtime permission on API 33+; the concept does not exist below.
        val postNotificationsGranted: Boolean? = if (sdkInt >= 33) {
            runCatching {
                context.checkSelfPermission(
                    Manifest.permission.POST_NOTIFICATIONS,
                ) == PackageManager.PERMISSION_GRANTED
            }.getOrNull()
        } else {
            null
        }
        // A channel that was never created (no ring yet) follows the app
        // default, which is enabled; only an explicit IMPORTANCE_NONE
        // reports disabled.
        val ringingChannelEnabled: Boolean? = runCatching {
            val channel = notificationManager.getNotificationChannel(
                AlarmForegroundService.RINGING_CHANNEL_ID,
            )
            channel == null || channel.importance != NotificationManager.IMPORTANCE_NONE
        }.getOrNull()
        val canScheduleExact: Boolean? = if (sdkInt >= Build.VERSION_CODES.S) {
            runCatching { alarmManager.canScheduleExactAlarms() }.getOrNull()
        } else {
            true
        }
        val fullScreenIntentAllowed: Boolean? =
            if (sdkInt >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                runCatching {
                    notificationManager.canUseFullScreenIntent()
                }.getOrNull()
            } else {
                null
            }
        val batteryExempt: Boolean? = runCatching {
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        }.getOrNull()
        val bootReceiverEnabled: Boolean? = runCatching {
            when (
                context.packageManager.getComponentEnabledSetting(
                    ComponentName(context, BootReceiver::class.java),
                )
            ) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                -> true
                else -> false
            }
        }.getOrNull()
        return mapOf(
            "sdkInt" to sdkInt,
            "notificationsEnabled" to notificationsEnabled,
            "postNotificationsGranted" to postNotificationsGranted,
            "ringingChannelEnabled" to ringingChannelEnabled,
            "canScheduleExactAlarms" to canScheduleExact,
            "fullScreenIntentAllowed" to fullScreenIntentAllowed,
            "batteryExempt" to batteryExempt,
            "bootReceiverEnabled" to bootReceiverEnabled,
        )
    }

    /**
     * Opens the system settings page for [target], checking resolvability
     * first so OEMs without the page never crash us. Candidates fall back
     * to the app-details page; targets with no page on this Android
     * version return false instead of opening something unrelated.
     */
    private fun openSettingsTarget(target: String): Boolean {
        val packageName = context.packageName
        val packageUri = Uri.parse("package:$packageName")
        val candidates: List<Intent> = when (target) {
            "notifications" -> listOf(
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .putExtra(
                        Settings.EXTRA_CHANNEL_ID,
                        AlarmForegroundService.RINGING_CHANNEL_ID,
                    ),
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
            )
            "exactAlarm" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
                listOf(
                    Intent(
                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                        packageUri,
                    ),
                )
            }
            "fullScreen" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return false
                listOf(
                    Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                        packageUri,
                    ),
                )
            }
            // The settings list needs no permission; the direct exemption
            // request action would need REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
            // in the manifest (Play-policy sensitive), so we do not use it.
            "battery" -> listOf(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS),
            )
            "appDetails" -> emptyList()
            else -> throw IllegalArgumentException("Unknown settings target: $target")
        }
        val fallback =
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri)
        for (intent in candidates + fallback) {
            if (launchIfResolvable(intent)) return true
        }
        return false
    }

    /**
     * Starts [intent] when some activity resolves it. Never throws: every
     * failure (unresolvable, OEM quirk, SecurityException) is a `false`
     * the caller can fall back from or report honestly.
     */
    private fun launchIfResolvable(intent: Intent): Boolean {
        return try {
            val resolved = context.packageManager.queryIntentActivities(
                intent,
                PackageManager.MATCH_DEFAULT_ONLY,
            )
            if (resolved.isEmpty()) {
                Log.d("AlarmX", "No activity for settings intent: ${intent.action}.")
                return false
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(intent)
            true
        } catch (t: Throwable) {
            Log.w("AlarmX", "Settings intent failed: ${intent.action}.", t)
            false
        }
    }

    /**
     * Builds the PendingIntent that AlarmManager uses to fire [AlarmReceiver]
     * for the given alarm. Used by both schedule and cancel so the two
     * PendingIntents are equivalent (a precondition for cancel to work).
     *
     * `FLAG_IMMUTABLE` is required on API 31+ and is safe here because the
     * extras are frozen when the PendingIntent is created (nothing ever
     * mutates them afterwards). For persisted alarms the fire config is
     * frozen into the extras so the receiver can verify and forward it with
     * no database or engine access; legacy test alarms carry the id only.
     */
    private fun buildAlarmPendingIntent(
        alarmId: Int,
        triggerAtMillis: Long? = null,
        fireLabel: String? = null,
        fireVibration: Boolean = true,
        isPersisted: Boolean = false,
    ): PendingIntent {
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = "com.alarmx.app.alarmx.ALARM_FIRE"
            putExtra(AlarmReceiver.EXTRA_ALARM_ID, alarmId)
            if (isPersisted && triggerAtMillis != null) {
                putExtra(AlarmReceiver.EXTRA_TRIGGER_AT_MILLIS, triggerAtMillis)
                if (fireLabel != null) {
                    putExtra(AlarmReceiver.EXTRA_LABEL, fireLabel)
                }
                putExtra(AlarmReceiver.EXTRA_VIBRATION_ENABLED, fireVibration)
            }
        }
        return PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
