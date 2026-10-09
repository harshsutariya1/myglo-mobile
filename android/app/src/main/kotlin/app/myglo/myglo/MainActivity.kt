package app.myglo.myglo

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.CalendarContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "addEvent" -> addCalendarEvent(call, result)
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "mapsAvailable" -> result.success(!mapsApiKey().isNullOrBlank())
                    "notificationsEnabled" ->
                        result.success(getSystemService(NotificationManager::class.java)?.areNotificationsEnabled() ?: false)
                    "openNotificationSettings" -> result.success(openNotificationSettings())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * The channel booking pushes are posted to (FCM's default channel, see the
     * manifest). Creating an existing channel again is a no-op, and the user's
     * own changes to it are kept.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            getString(R.string.notification_channel_bookings_id),
            getString(R.string.notification_channel_bookings_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.notification_channel_bookings_description)
            enableVibration(true)
            setShowBadge(true)
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(channel)
    }

    /** The Maps SDK key injected into the manifest at build time, if any. */
    private fun mapsApiKey(): String? = try {
        val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getApplicationInfo(packageName, PackageManager.ApplicationInfoFlags.of(PackageManager.GET_META_DATA.toLong()))
        } else {
            @Suppress("DEPRECATION")
            packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        }
        info.metaData?.getString("com.google.android.geo.API_KEY")
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    /** Opens this app's notification settings, falling back to its app info page. */
    private fun openNotificationSettings(): Boolean {
        val notificationSettings = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        }
        val appDetails = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))
        for (intent in listOf(notificationSettings, appDetails)) {
            try {
                startActivity(intent)
                return true
            } catch (e: ActivityNotFoundException) {
                continue
            }
        }
        return false
    }

    /**
     * Opens the user's calendar app on a pre-filled "new event" screen. The
     * calendar app does the saving, so no calendar permission is needed.
     */
    private fun addCalendarEvent(call: MethodCall, result: MethodChannel.Result) {
        val title = call.argument<String>("title")
        val start = call.argument<Number>("startMillis")?.toLong()
        val end = call.argument<Number>("endMillis")?.toLong()
        if (title.isNullOrBlank() || start == null || end == null) {
            result.error("invalid_arguments", "title, startMillis and endMillis are required", null)
            return
        }

        val intent = Intent(Intent.ACTION_INSERT).apply {
            data = CalendarContract.Events.CONTENT_URI
            putExtra(CalendarContract.Events.TITLE, title)
            putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start)
            putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end)
            call.argument<String>("location")?.let { putExtra(CalendarContract.Events.EVENT_LOCATION, it) }
            call.argument<String>("notes")?.let { putExtra(CalendarContract.Events.DESCRIPTION, it) }
            call.argument<String>("timeZone")?.let { putExtra(CalendarContract.Events.EVENT_TIMEZONE, it) }
        }

        try {
            startActivity(intent)
            result.success("opened")
        } catch (e: ActivityNotFoundException) {
            result.error("unavailable", "No calendar app can add events", null)
        }
    }

    private companion object {
        const val CALENDAR_CHANNEL = "app.myglo/calendar"
        const val SYSTEM_CHANNEL = "app.myglo/system"
    }
}
