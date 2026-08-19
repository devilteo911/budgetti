package com.devilteo911.budgetti.budgetti

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

// ponytail: prefix match, not an exact id — Revolut ships regional/variant
// package names and an exact string silently captures nothing when it drifts.
private const val REVOLUT_PKG_PREFIX = "com.revolut"
private const val BUFFER_FILE = "revolut_notifications.json"
private const val MAX_BUFFERED = 300

/// Captures Revolut card-spend notifications into a JSON buffer file that the
/// Flutter side drains on sync. Inert until the user grants Notification access
/// in system settings. Buffer lives in getFilesDir(), which Flutter reaches via
/// getApplicationSupportDirectory(), so pulls work from any isolate.
class RevolutNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!sbn.packageName.startsWith(REVOLUT_PKG_PREFIX)) return
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

        // The Flutter side drains every 15 min, so this only bites if the app
        // never runs. Drop the oldest rather than let the file (and the O(n)
        // rewrite on every notification) grow without bound.
        // ponytail: fixed cap; if drains can lag for days, buffer to SQLite instead.
        while (buffer.length() > MAX_BUFFERED) buffer.remove(0)

        writeBuffer(buffer)
    }

    private fun readBuffer(): JSONArray = try {
        JSONArray(openFileInput(BUFFER_FILE).bufferedReader().use { it.readText() })
    } catch (_: Exception) {
        JSONArray()
    }

    private fun writeBuffer(arr: JSONArray) {
        // Write-then-rename: openFileOutput truncates first, so a kill
        // mid-write left a truncated file the Dart drain would read as
        // corrupt JSON. The rename window is single-instruction small.
        val tmp = File(getFilesDir(), "$BUFFER_FILE.tmp")
        openFileOutput("$BUFFER_FILE.tmp", MODE_PRIVATE)
            .use { it.write(arr.toString().toByteArray()) }
        val target = File(getFilesDir(), BUFFER_FILE)
        target.delete()
        if (!tmp.renameTo(target)) {
            openFileOutput(BUFFER_FILE, MODE_PRIVATE)
                .use { it.write(arr.toString().toByteArray()) }
        }
    }
}
