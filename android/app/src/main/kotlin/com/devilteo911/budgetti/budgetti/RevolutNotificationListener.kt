package com.devilteo911.budgetti.budgetti

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

private const val REVOLUT_PKG = "com.revolut.bug"
private const val BUFFER_FILE = "revolut_notifications.json"

/// Captures Revolut card-spend notifications into a JSON buffer file that the
/// Flutter side drains on sync. Inert until the user grants Notification access
/// in system settings. Buffer lives in getFilesDir(), which Flutter reaches via
/// getApplicationSupportDirectory(), so pulls work from any isolate.
class RevolutNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != REVOLUT_PKG) return
        val n = sbn.notification ?: return
        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT))?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return

        // A transaction's notification can re-post (updates, summaries); dedupe
        // by the stable notification key so the buffer holds each spend once.
        val key = sbn.key
        val buffer = readBuffer()
        for (i in 0 until buffer.length()) {
            if (buffer.optJSONObject(i)?.optString("key") == key) return
        }

        val whenMs = if (n.`when` != 0L) n.`when` else sbn.postTime
        buffer.put(JSONObject().apply {
            put("key", key)
            put("title", title)
            put("text", text)
            put("when", whenMs)
        })
        writeBuffer(buffer)
    }

    private fun readBuffer(): JSONArray = try {
        JSONArray(openFileInput(BUFFER_FILE).bufferedReader().use { it.readText() })
    } catch (_: Exception) {
        JSONArray()
    }

    private fun writeBuffer(arr: JSONArray) {
        openFileOutput(BUFFER_FILE, MODE_PRIVATE).use { it.write(arr.toString().toByteArray()) }
    }
}
