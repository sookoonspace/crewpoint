package space.sookoon.crewpoint_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.TimeZone

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
 *
 * The urgent channel keeps `setBypassDnd(true)` as a semantic
 * declaration — harmless without `NOTIFICATION_POLICY_ACCESS_GRANTED`,
 * and useful if a future build re-introduces the DND-access opt-in.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "crewpoint/notification_channels"
        private const val DEVICE_INFO_CHANNEL = "crewpoint/device_info"
        private const val METHOD_REGISTER = "registerChannels"
        private const val METHOD_GET_LOCAL_TIMEZONE = "getLocalTimezone"

        /** Channel id of the urgent chat channel — see
         *  `notification_channels.dart`. Centralised so the Kotlin side
         *  doesn't drift from the Dart spec table.
         */
        private const val URGENT_CHANNEL_ID = "crewpoint_chat_urgent"
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

        // Dedicated device-info channel (Phase 5.2). Currently exposes
        // only the device's IANA timezone; new methods can land here as
        // future phases need them.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_INFO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                METHOD_GET_LOCAL_TIMEZONE -> {
                    result.success(TimeZone.getDefault().id)
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
                // Urgent chat: declare bypass intent. The OS gates this
                // on NOTIFICATION_POLICY_ACCESS_GRANTED; harmless without
                // the grant, which we no longer request in V1/V2.
                if (id == URGENT_CHANNEL_ID) {
                    setBypassDnd(true)
                }
            }
            nm.createNotificationChannel(channel)
        }
    }
}
