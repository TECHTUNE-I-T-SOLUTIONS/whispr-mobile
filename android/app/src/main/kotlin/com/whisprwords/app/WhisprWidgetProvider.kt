package com.whisprwords.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class WhisprWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        render(context, appWidgetManager, appWidgetIds)
        WhisprWidgetRefresher.refreshPublic(context) {
            render(context, appWidgetManager, appWidgetIds)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH) {
            updateAllWidgets(context)
        }
    }

    companion object {
        const val ACTION_REFRESH = "com.whisprwords.app.WIDGET_REFRESH"

        fun hasWidgets(context: Context): Boolean = widgetIds(context).isNotEmpty()

        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = widgetIds(context)
            if (ids.isNotEmpty()) render(context, manager, ids)
        }

        private fun widgetIds(context: Context): IntArray =
            AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, WhisprWidgetProvider::class.java))

        private fun render(context: Context, manager: AppWidgetManager, ids: IntArray) {
            val snapshot = WidgetSnapshotStore.load(context)
            for (id in ids) {
                val views = RemoteViews(context.packageName, R.layout.whispr_widget)
                views.setTextViewText(R.id.widget_counts, snapshot.countsLine)
                views.setTextViewText(R.id.widget_title, snapshot.displayTitle)
                views.setTextViewText(R.id.widget_body, snapshot.displayBody)
                views.setTextViewText(R.id.widget_updated, snapshot.updatedLabel)

                views.setOnClickPendingIntent(
                    R.id.widget_root,
                    deepLink(context, snapshot.displayLink, 101),
                )
                views.setOnClickPendingIntent(
                    R.id.widget_open_notifications,
                    deepLink(context, "whispr://app/notifications", 102),
                )
                manager.updateAppWidget(id, views)
            }
        }

        private fun deepLink(context: Context, link: String, requestCode: Int): PendingIntent {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(link))
            intent.setPackage(context.packageName)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            return PendingIntent.getActivity(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
    }
}
