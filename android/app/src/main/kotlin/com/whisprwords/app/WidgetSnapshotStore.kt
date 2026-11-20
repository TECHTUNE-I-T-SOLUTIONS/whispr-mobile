package com.whisprwords.app

import android.content.Context
import org.json.JSONObject

/** Cached widget data. Public feed refreshes never overwrite signed-in counts. */
data class WidgetSnapshot(
    val unreadCount: Int,
    val postCount: Int,
    val streakDays: Int,
    val latestTitle: String,
    val latestBody: String,
    val latestLink: String,
    val updatedAtMillis: Long,
    val signedIn: Boolean,
    val publicTitle: String,
    val publicBody: String,
    val publicLink: String,
    val publicUpdatedAtMillis: Long,
) {
    val displayTitle: String
        get() = if (publicUpdatedAtMillis > updatedAtMillis && publicTitle.isNotBlank()) {
            publicTitle
        } else {
            latestTitle
        }

    val displayBody: String
        get() = if (publicUpdatedAtMillis > updatedAtMillis && publicTitle.isNotBlank()) {
            publicBody
        } else {
            latestBody
        }

    val displayLink: String
        get() = if (publicUpdatedAtMillis > updatedAtMillis && publicTitle.isNotBlank()) {
            publicLink
        } else {
            latestLink
        }

    val countsLine: String
        get() = if (!signedIn) {
            "Live from Whispr"
        } else {
            buildString {
                append(unreadCount).append(" unread")
                if (postCount > 0) append(" · ").append(postCount).append(" posts")
                if (streakDays > 0) append(" · ").append(streakDays).append("d streak")
            }
        }

    val updatedLabel: String
        get() {
            if (updatedAtMillis <= 0L) return "Not synced yet"
            val minutes = ((System.currentTimeMillis() - updatedAtMillis) / 60_000L).coerceAtLeast(0L)
            return when {
                minutes < 1L -> "Updated just now"
                minutes < 60L -> "Updated ${minutes}m ago"
                minutes < 1_440L -> "Updated ${minutes / 60L}h ago"
                else -> "Updated ${minutes / 1_440L}d ago"
            }
        }

    companion object {
        fun empty(): WidgetSnapshot = WidgetSnapshot(
            unreadCount = 0,
            postCount = 0,
            streakDays = 0,
            latestTitle = "Your Whispr is waiting",
            latestBody = "Open Whispr to load your latest updates.",
            latestLink = "whispr://app/home",
            updatedAtMillis = 0L,
            signedIn = false,
            publicTitle = "",
            publicBody = "",
            publicLink = "",
            publicUpdatedAtMillis = 0L,
        )

        fun fromJson(json: JSONObject): WidgetSnapshot {
            val public = json.optJSONObject("public_json") ?: JSONObject()
            return WidgetSnapshot(
            unreadCount = json.optInt("unreadCount", 0).coerceAtLeast(0),
            postCount = json.optInt("postCount", 0).coerceAtLeast(0),
            streakDays = json.optInt("streakDays", 0).coerceAtLeast(0),
            latestTitle = json.optString("latestTitle", "").ifBlank { "Whispr" },
            latestBody = json.optString("latestBody", "").ifBlank { "Open Whispr for updates." },
            latestLink = safeLink(json.optString("latestLink", "")),
            updatedAtMillis = parseTimestamp(json.optString("updatedAt", "")),
            signedIn = json.optBoolean("signedIn", false),
            publicTitle = public.optString("publicTitle", ""),
            publicBody = public.optString("publicBody", ""),
            publicLink = safeLink(public.optString("publicLink", "")),
            publicUpdatedAtMillis = public.optLong("publicUpdatedAtMillis", 0L),
            )
        }

        private fun safeLink(raw: String?): String {
            val value = raw?.trim().orEmpty()
            if (value.isEmpty()) return "whispr://app/home"
            return try {
                val uri = android.net.Uri.parse(value)
                when (uri.scheme) {
                    "whispr" -> value
                    "https" -> if (uri.host == "whisprwords.com" || uri.host == "www.whisprwords.com") {
                        value
                    } else {
                        "whispr://app/home"
                    }
                    else -> "whispr://app/home"
                }
            } catch (_: Exception) {
                "whispr://app/home"
            }
        }

        private fun parseTimestamp(raw: String?): Long {
            if (raw.isNullOrEmpty()) return 0L
            return try {
                java.time.Instant.parse(raw).toEpochMilli()
            } catch (_: Exception) {
                try {
                    java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
                        .apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }
                        .parse(raw)?.time ?: 0L
                } catch (_: Exception) {
                    0L
                }
            }
        }
    }
}

object WidgetSnapshotStore {
    private const val PREFS = "whispr_widget_prefs"
    private const val KEY_SNAPSHOT = "snapshot_json"
    private const val KEY_PUBLIC_JSON = "public_json"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveSnapshot(context: Context, json: JSONObject) {
        val existing = loadRaw(context)
        // Preserve the last public refresh when Dart pushes a fresh snapshot.
        val public = existing.optJSONObject(KEY_PUBLIC_JSON)
        val merged = JSONObject(json.toString())
        if (public != null) {
            merged.put(KEY_PUBLIC_JSON, public)
        }
        prefs(context).edit().putString(KEY_SNAPSHOT, merged.toString()).apply()
    }

    fun savePublic(context: Context, title: String, body: String, link: String) {
        val json = loadRaw(context)
        val public = JSONObject().apply {
            put("publicTitle", title)
            put("publicBody", body)
            put("publicLink", link)
            put("publicUpdatedAtMillis", System.currentTimeMillis())
        }
        json.put(KEY_PUBLIC_JSON, public)
        prefs(context).edit().putString(KEY_SNAPSHOT, json.toString()).apply()
    }

    fun load(context: Context): WidgetSnapshot = try {
        WidgetSnapshot.fromJson(loadRaw(context))
    } catch (_: Exception) {
        WidgetSnapshot.empty()
    }

    private fun loadRaw(context: Context): JSONObject {
        val raw = prefs(context).getString(KEY_SNAPSHOT, null) ?: return JSONObject()
        return try {
            JSONObject(raw)
        } catch (_: Exception) {
            JSONObject()
        }
    }
}
