package com.alarmx.app.alarmx

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Receives alarm broadcasts scheduled by [MainActivity] via AlarmManager.
 *
 * At this stage the receiver only:
 *   1. Logs that the alarm fired (so we can confirm end-to-end from logcat).
 *   2. Posts a simple test notification on the `alarmx_test_channel` channel
 *      so the pipeline is observable from the system tray.
 *
 * The full-screen alarm UI, sound, vibration and mission gate are out of
 * scope for this phase — they will be added once the broadcast wiring is
 * proven to work end-to-end.
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "AlarmX"
        private const val TEST_CHANNEL_ID = "alarmx_test_channel"
        private const val TEST_CHANNEL_NAME = "AlarmX Test"
        private const val TEST_NOTIFICATION_ID = 1000

        /** Intent extra key carrying the alarm row id. */
        const val EXTRA_ALARM_ID = "alarm_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
        Log.d(TAG, "Alarm fired for id: $alarmId")

        if (alarmId < 0) {
            Log.w(TAG, "Ignoring alarm broadcast with missing/invalid alarm_id extra")
            return
        }

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        ensureTestChannel(notificationManager)

        val tapIntent = Intent(context, MainActivity::class.java).apply {
            // NEW_TASK + CLEAR_TOP so launching from the notification starts a
            // clean alarm UI flow once that screen exists.
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_ALARM_ID, alarmId)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            alarmId,
            tapIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, TEST_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Alarm Fired")
            .setContentText("Alarm $alarmId triggered (test notification).")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(contentPendingIntent)
            .build()

        // POST_NOTIFICATIONS is a runtime permission on API 33+; if the user
        // has not granted it yet this call is silently dropped by the system.
        // The broadcast still fires, so logcat will show the alarm went off.
        try {
            notificationManager.notify(TEST_NOTIFICATION_ID + alarmId, notification)
        } catch (securityException: SecurityException) {
            Log.w(
                TAG,
                "Notification post denied (missing POST_NOTIFICATIONS?): " +
                    securityException.message,
            )
        }
    }

    private fun ensureTestChannel(notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (notificationManager.getNotificationChannel(TEST_CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            TEST_CHANNEL_ID,
            TEST_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Temporary channel used while the alarm pipeline is being wired up."
        }
        notificationManager.createNotificationChannel(channel)
    }
}
