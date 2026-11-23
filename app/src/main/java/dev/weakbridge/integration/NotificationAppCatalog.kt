package dev.weakbridge.integration

import dev.weakbridge.R
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF

/** Names only; category glyphs are drawn locally and do not use third-party logo assets. */
object NotificationAppCatalog {
    data class App(val id: String, val name: String)

    val knownApps =
        listOf(
            App("com.apple.MobileSMS", "Messages"),
            App("com.apple.mobilephone", "Phone"),
            App("com.apple.mobilemail", "Mail"),
            App("com.apple.mobilecal", "Calendar"),
            App("com.apple.reminders", "Reminders"),
            App("com.apple.facetime", "FaceTime"),
            App("com.apple.Maps", "Maps"),
            App("com.apple.Health", "Health"),
            App("com.apple.Music", "Music"),
            App("com.apple.mobilenotes", "Notes"),
            App("net.whatsapp.WhatsApp", "WhatsApp"),
            App("ph.telegra.Telegraph", "Telegram"),
            App("com.hammerandchisel.discord", "Discord"),
            App("com.facebook.Messenger", "Messenger"),
            App("com.burbn.instagram", "Instagram"),
            App("com.google.Gmail", "Gmail"),
            App("com.microsoft.Office.Outlook", "Outlook"),
            App("com.tinyspeck.chatlyio", "Slack"),
            App("com.microsoft.skype.teams", "Teams"),
            App("com.spotify.client", "Spotify"),
        )
    private val names = knownApps.associate { it.id to it.name }

    fun displayName(appId: String, ancsName: String? = null): String =
        ancsName?.takeIf { it.isNotBlank() }
            ?: names[appId]
            ?: appId.substringAfterLast('.').ifBlank { "iPhone" }

    fun icon(category: Int): Int =
        when (category) {
            1,
            2,
            3 -> R.drawable.ic_notification_call
            5 -> R.drawable.ic_notification_calendar
            6 -> R.drawable.ic_notification_mail
            8 -> R.drawable.ic_notification_health
            10 -> R.drawable.ic_notification_location
            11 -> R.drawable.ic_notification_music
            else -> R.drawable.ic_notification_message
        }

    /**
     * ANCS sends an app identifier and display name, not the iPhone app's image asset.
     * Give every sender a recognizable, locally generated badge without network or cloud lookup.
     */
    fun largeIcon(context: Context, appId: String, appName: String): Bitmap {
        val density = context.resources.displayMetrics.density
        val size = (48 * density).toInt().coerceAtLeast(48)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val hue = Math.floorMod(appId.hashCode(), 360).toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = android.graphics.Color.HSVToColor(floatArrayOf(hue, 0.48f, 0.62f))
        val inset = size * 0.04f
        val rect = RectF(inset, inset, size - inset, size - inset)
        canvas.drawRoundRect(rect, size * 0.24f, size * 0.24f, paint)
        paint.color = android.graphics.Color.WHITE
        paint.textAlign = Paint.Align.CENTER
        paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
        paint.textSize = size * if (appName.length > 10) 0.35f else 0.42f
        val letters = appName.trim().split(Regex("\\s+")).mapNotNull { it.firstOrNull() }.take(2)
        val mark = when {
            letters.size == 2 -> "${letters[0]}${letters[1]}"
            appName.isNotBlank() -> appName.take(1).uppercase()
            else -> "?"
        }
        val baseline = (size - (paint.ascent() + paint.descent())) / 2f
        canvas.drawText(mark, size / 2f, baseline, paint)
        return bitmap
    }
}
