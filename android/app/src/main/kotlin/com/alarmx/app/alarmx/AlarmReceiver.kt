package com.alarmx.app.alarmx

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Receives alarm broadcasts scheduled by [MainActivity] via AlarmManager and
 * hands them to [AlarmForegroundService], which shows the ongoing ringing
 * notification and plays the alarm ringtone + vibration.
 *
 * Two kinds of broadcasts arrive here:
 * - Persisted alarms carry a schedule token ([EXTRA_TRIGGER_AT_MILLIS]) plus
 *   the frozen fire config. The token is verified against [AlarmScheduleLedger]
 *   and the broadcast is dropped (no ring, no crash, one warning log) when it
 *   does not match the current schedule — e.g. a stale delivery racing a
 *   cancel/reschedule. The config is forwarded to the service untouched.
 * - Legacy test alarms carry the id only and bypass verification entirely,
 *   keeping the exact Phase 1.2 behavior.
 *
 * The receiver itself posts no alarm notification. Only if the foreground
 * service cannot be started (background-start restriction on Android 12+, or
 * missing notification permission on Android 13+) does it fall back to a
 * plain high-priority "missed alarm" notification so the event stays visible
 * instead of crashing the receiver.
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmX"

        /** Intent extra key carrying the alarm row id. */
        const val EXTRA_ALARM_ID = "alarm_id"

        /**
         * Schedule-token extra key: the trigger this delivery was scheduled
         * for. Presence marks a persisted alarm; absence a legacy test alarm.
         */
        const val EXTRA_TRIGGER_AT_MILLIS = "trigger_at_millis"

        /** Optional fire-config extra key carrying the alarm label. */
        const val EXTRA_LABEL = "label"

        /** Fire-config extra key carrying the vibration flag. */
        const val EXTRA_VIBRATION_ENABLED = "vibration_enabled"

        private const val FALLBACK_CHANNEL_ID = "alarmx_missed_channel"
        private const val FALLBACK_CHANNEL_NAME = "AlarmX Alerts"
        private const val FALLBACK_NOTIFICATION_ID = 3000
    }

    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        Log.d(TAG, "Alarm fired for id: $alarmId")

        if (alarmId < 0) {
            Log.w(TAG, "Ignoring alarm broadcast with missing/invalid alarm_id extra")
            return
        }

        val isPersisted = intent.hasExtra(EXTRA_TRIGGER_AT_MILLIS)
        if (isPersisted) {
            val triggerAtMillis = intent.getLongExtra(EXTRA_TRIGGER_AT_MILLIS, -1L)
            if (!AlarmScheduleLedger.isCurrentSchedule(context, alarmId, triggerAtMillis)) {
                Log.w(
                    TAG,
                    "Ignoring stale/cancelled schedule for alarm id: $alarmId " +
                        "(trigger=$triggerAtMillis)",
                )
                return
            }
            Log.d(TAG, "Persisted alarm verified for id: $alarmId")
        } else {
            Log.d(TAG, "Legacy test alarm for id: $alarmId (no schedule token)")
        }

        val serviceIntent = Intent(context, AlarmForegroundService::class.java).apply {
            action = AlarmForegroundService.ACTION_START
            putExtra(AlarmForegroundService.EXTRA_ALARM_ID, alarmId)
            if (isPersisted) {
                intent.getStringExtra(EXTRA_LABEL)?.let { label ->
                    putExtra(AlarmForegroundService.EXTRA_LABEL, label)
                }
                putExtra(
                    AlarmForegroundService.EXTRA_VIBRATION_ENABLED,
                    intent.getBooleanExtra(EXTRA_VIBRATION_ENABLED, true),
                )
            }
        }
        try {
            ContextCompat.startForegroundService(context, serviceIntent)
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException (Android 12+ background
            // start restriction) or SecurityException (Android 13+ without
            // POST_NOTIFICATIONS): degrade to a visible notification.
            Log.w(TAG, "Could not start foreground service; showing fallback notification.", e)
            showFallbackNotification(context, alarmId)
        }
    }

    private fun showFallbackNotification(context: Context, alarmId: Int) {
        try {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationManager.getNotificationChannel(FALLBACK_CHANNEL_ID) == null) {
                notificationManager.createNotificationChannel(
                    NotificationChannel(
                        FALLBACK_CHANNEL_ID,
                        FALLBACK_CHANNEL_NAME,
                        NotificationManager.IMPORTANCE_HIGH,
                    ).apply {
                        description = "Used only when the ringing service cannot be started."
                    },
                )
            }
            val tapIntent = PendingIntent.getActivity(
                context,
                alarmId,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra(EXTRA_ALARM_ID, alarmId)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val notification = NotificationCompat.Builder(context, FALLBACK_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("AlarmX")
                .setContentText("Alarm $alarmId went off. Tap to open.")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(tapIntent)
                .build()
            notificationManager.notify(FALLBACK_NOTIFICATION_ID + alarmId, notification)
        } catch (e: Exception) {
            Log.w(TAG, "Fallback notification failed.", e)
        }
    }
}
