package com.alarmx.app.alarmx

import android.app.Activity
import android.content.Intent

/**
 * Activity-result plumbing for the alarm-sound pickers.
 *
 * [MainActivity] builds this host in `onCreate` and hands it to
 * [AlarmSchedulerChannelHandler]; the handler's `pickAudioFile` /
 * `pickSystemRingtone` methods launch through it, and the activity's
 * `onActivityResult` dispatches back here. The headless boot engine
 * never builds a host, so those methods answer null there — pickers
 * need a foreground activity.
 *
 * Framework `onActivityResult` (not the Activity Result API): Flutter's
 * `FlutterActivity` extends the framework `Activity`, which has no
 * `registerForActivityResult`. The deprecated launch path is fully
 * functional and warning-only.
 *
 * One in-flight pick per request code: launching while a callback is
 * still pending fails the older one with null (single-threaded UI: this
 * only happens on overlapping Dart calls).
 */
class AudioPickerHost(private val activity: Activity) {

    companion object {
        private const val REQUEST_OPEN_DOCUMENT = 9001
        private const val REQUEST_RINGTONE = 9002
    }

    private var openDocumentCallback: ((Intent?) -> Unit)? = null
    private var ringtoneCallback: ((Intent?) -> Unit)? = null

    /** Launches the SAF document picker, failing any older pending pick. */
    fun launchOpenDocument(intent: Intent, onResult: (Intent?) -> Unit) {
        openDocumentCallback?.invoke(null)
        openDocumentCallback = onResult
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, REQUEST_OPEN_DOCUMENT)
    }

    /** Launches the system ringtone picker, failing any older pending pick. */
    fun launchRingtonePicker(intent: Intent, onResult: (Intent?) -> Unit) {
        ringtoneCallback?.invoke(null)
        ringtoneCallback = onResult
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, REQUEST_RINGTONE)
    }

    /**
     * Dispatches an activity result to the pending pick. Returns true
     * when the [requestCode] belongs to a picker (consumed).
     */
    fun dispatch(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val callback = when (requestCode) {
            REQUEST_OPEN_DOCUMENT -> openDocumentCallback.also {
                openDocumentCallback = null
            }
            REQUEST_RINGTONE -> ringtoneCallback.also {
                ringtoneCallback = null
            }
            else -> return false
        }
        val delivered = if (resultCode == Activity.RESULT_OK) data else null
        callback?.invoke(delivered)
        return true
    }
}
