package space.sookoon.crewpoint_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Receives notification-channel specs from
 * `lib/app/core/services/notification_channels.dart` over the
 * `crewpoint/notification_channels` MethodChannel and registers them with
 * the OS. Required because Flutter has no first-party channel API and
 * Android 8.0+ refuses notifications without a declared channel.
 *
 * Replays are idempotent: `createNotificationChannel(...)` updates the
 * existing channel definition without resetting user-visible settings
 * (importance, sound) the user may have changed in System Settings.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "crewpoint/notification_channels"
        private const val METHOD_REGISTER = "registerChannels"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_REGISTER -> {
                        @Suppress("UNCHECKED_CAST")
                        val specs =
                            call.argument<List<Map<String, Any>>>("channels")
                                ?: emptyList()
                        registerChannels(specs)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerChannels(specs: List<Map<String, Any>>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (spec in specs) {
            val id = spec["id"] as? String ?: continue
            val name = spec["name"] as? String ?: id
            val description = spec["description"] as? String
            val importance = (spec["importance"] as? Int)
                ?: NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(id, name, importance).apply {
                if (description != null) this.description = description
            }
            nm.createNotificationChannel(channel)
        }
    }
}
