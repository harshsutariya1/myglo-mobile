package app.myglo.myglo

import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "addEvent" -> addCalendarEvent(call, result)
                    else -> result.notImplemented()
                }
            }
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
    }
}
