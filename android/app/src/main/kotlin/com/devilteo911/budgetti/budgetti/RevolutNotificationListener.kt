package com.devilteo911.budgetti.budgetti

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

// ponytail: prefix match, not an exact id — Revolut and PayPal ship
// regional/variant package names and an exact string silently captures nothing
// when it drifts.
private const val REVOLUT_PKG_PREFIX = "com.revolut"
private const val PAYPAL_PKG_PREFIX = "com.paypal"
// One buffer file per source, so each Flutter-side switch drains only its own
// and the entries need not record who posted them (they stay {key,title,text,when}).
private const val REVOLUT_BUFFER = "revolut_notifications.json"
private const val PAYPAL_BUFFER = "paypal_notifications.json"
private const val MAX_BUFFERED = 300

/// Captures Revolut and PayPal notifications into one JSON buffer file per
/// source that the Flutter side drains on sync. Inert until the user grants
/// Notification access in system settings. Buffers live in getFilesDir(), which
/// Flutter reaches via getApplicationSupportDirectory(), so pulls work from any
/// isolate.
///
/// The class keeps its Revolut-era name and package on purpose: Android stores
/// the notification-access grant per component name, so renaming or moving it
/// would silently revoke the access the user already gave. Only the manifest
/// label changes.
class RevolutNotificationListener : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        // Debug builds also accept pushes posted from the adb shell, so
        // `adb shell cmd notification post` can stand in for Revolut (or, with a
        // tag starting `paypal`, for PayPal) and drive the whole path (listener,
        // buffer, drain, parser, inbox) without a real payment. BuildConfig.DEBUG
        // is a compile-time false in release and the package and tag names are
        // deliberately literals here, not consts: a top-level const would keep
        // the string in the release class file.
        val pkg = sbn.packageName
        val bufferFile = when {
            pkg.startsWith(REVOLUT_PKG_PREFIX) -> REVOLUT_BUFFER
            pkg.startsWith(PAYPAL_PKG_PREFIX) -> PAYPAL_BUFFER
            BuildConfig.DEBUG && pkg == "com.android.shell" ->
                if (sbn.tag?.startsWith("paypal") == true) PAYPAL_BUFFER else REVOLUT_BUFFER
            else -> return
        }
        val n = sbn.notification ?: return
        val extras = n.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (extras.getCharSequence(Notification.EXTRA_TEXT)
            ?: extras.getCharSequence(Notification.EXTRA_BIG_TEXT))?.toString().orEmpty()
        if (title.isBlank() && text.isBlank()) return

        // A transaction's notification can re-post (updates, summaries); dedupe
        // by the stable notification key so the buffer holds each spend once.
        val key = sbn.key
        val buffer = readBuffer(bufferFile)
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

        writeBuffer(bufferFile, buffer)
    }

    private fun readBuffer(file: String): JSONArray = try {
        JSONArray(openFileInput(file).bufferedReader().use { it.readText() })
    } catch (_: Exception) {
        JSONArray()
    }

    private fun writeBuffer(file: String, arr: JSONArray) {
        // Write-then-rename: openFileOutput truncates first, so a kill
        // mid-write left a truncated file the Dart drain would read as
        // corrupt JSON. The rename window is single-instruction small.
        val tmp = File(getFilesDir(), "$file.tmp")
        openFileOutput("$file.tmp", MODE_PRIVATE)
            .use { it.write(arr.toString().toByteArray()) }
        val target = File(getFilesDir(), file)
        target.delete()
        if (!tmp.renameTo(target)) {
            openFileOutput(file, MODE_PRIVATE)
                .use { it.write(arr.toString().toByteArray()) }
        }
    }
}
