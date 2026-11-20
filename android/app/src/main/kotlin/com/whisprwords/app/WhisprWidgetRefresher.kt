package com.whisprwords.app

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Widget-triggered public feed refresh. It runs only on Android's own widget
 * update schedule, only on an unmetered connected network, and never sends a
 * user token or touches a development host.
 */
object WhisprWidgetRefresher {
    private const val TAG = "WhisprWidgetRefresh"
    private const val FEED_URL = "https://whisprwords.com/api/chronicles/posts/feed"
    private val executor = Executors.newSingleThreadExecutor()
    private val running = AtomicBoolean(false)

    fun refreshPublic(context: Context, onDone: () -> Unit) {
        val appContext = context.applicationContext
        if (!hasUnmeteredInternet(appContext) || !running.compareAndSet(false, true)) {
            onDone()
            return
        }

        executor.execute {
            try {
                val connection = URL(FEED_URL).openConnection() as HttpURLConnection
                connection.apply {
                    requestMethod = "GET"
                    connectTimeout = 10_000
                    readTimeout = 10_000
                    setRequestProperty("Accept", "application/json")
                }
                val response = connection.inputStream.bufferedReader().use { it.readText() }
                val posts = JSONObject(response).optJSONArray("posts")
                if (posts != null && posts.length() > 0) {
                    val post = posts.getJSONObject(0)
                    val title = post.optString("title", "").trim()
                    val slug = post.optString("slug", "").trim()
                    if (title.isNotEmpty() && slug.isNotEmpty()) {
                        val creator = post.optJSONObject("creator")
                        val author = creator?.optString("pen_name", "")?.trim().orEmpty()
                        val body = if (author.isEmpty()) "Fresh from Whispr" else "New from $author"
                        val link = "https://whisprwords.com/chronicles/$slug"
                        WidgetSnapshotStore.savePublic(appContext, title, body, link)
                    }
                }
            } catch (e: Exception) {
                // Keep the last good snapshot; the widget still renders.
                Log.d(TAG, "Public feed refresh skipped: ${e.message}")
            } finally {
                connectionSafeCleanup()
                running.set(false)
                Handler(Looper.getMainLooper()).post { onDone() }
            }
        }
    }

    private fun connectionSafeCleanup() {
        // HttpURLConnection is disconnected by the JVM when the stream closes;
        // this hook exists so future transport changes have one cleanup point.
    }

    private fun hasUnmeteredInternet(context: Context): Boolean {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        if (manager.isActiveNetworkMetered) return false
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }
}
