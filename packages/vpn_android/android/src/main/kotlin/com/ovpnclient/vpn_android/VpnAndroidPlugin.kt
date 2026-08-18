package com.ovpnclient.vpn_android

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import android.os.Handler
import android.os.Looper
import java.util.UUID
import java.util.concurrent.Executors

/** VpnAndroidPlugin — profiles, per-app VPN, OpenVPN connect via openvpn_library. */
class VpnAndroidPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var stageChannel: EventChannel
    private lateinit var logChannel: EventChannel
    private var stageSink: EventChannel.EventSink? = null
    private var logSink: EventChannel.EventSink? = null

    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private lateinit var appContext: android.content.Context
    private lateinit var store: ProfileStore
    private lateinit var vpn: OpenVpnController

    private var pendingConnectResult: Result? = null
    private var pendingPermissionResult: Result? = null
    private var pendingProfileId: String? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        store = ProfileStore(appContext)
        vpn = OpenVpnController(appContext, store)
        vpn.listener =
            object : OpenVpnController.Listener {
                override fun onStage(stage: String) {
                    activity?.runOnUiThread { stageSink?.success(stage) }
                }

                override fun onStats(
                    duration: String,
                    byteIn: String,
                    byteOut: String,
                    lastPacketReceive: String,
                ) {
                    activity?.runOnUiThread {
                        stageSink?.success(
                            mapOf(
                                "type" to "stats",
                                "duration" to duration,
                                "byteIn" to byteIn,
                                "byteOut" to byteOut,
                                "lastPacketReceive" to lastPacketReceive,
                            ),
                        )
                    }
                }

                override fun onLog(line: String) {
                    activity?.runOnUiThread { logSink?.success(line) }
                }
            }

        channel = MethodChannel(binding.binaryMessenger, "vpn_android")
        channel.setMethodCallHandler(this)
        stageChannel = EventChannel(binding.binaryMessenger, "vpn_android/stage")
        stageChannel.setStreamHandler(this)
        logChannel = EventChannel(binding.binaryMessenger, "vpn_android/logs")
        logChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    logSink = events
                }

                override fun onCancel(arguments: Any?) {
                    logSink = null
                }
            },
        )
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        try {
            when (call.method) {
                "getPlatformVersion" -> result.success("Android ${Build.VERSION.RELEASE}")
                "requestVpnPermission" -> requestVpnPermission(result)
                "listProfiles" -> result.success(store.list().map { it.toMap() })
                "getProfile" -> {
                    val id = call.argument<String>("id")
                    val p = id?.let { store.get(it) }
                    result.success(p?.toMap())
                }
                "importProfile" -> {
                    val name = call.argument<String>("name") ?: "Imported"
                    val config = call.argument<String>("ovpnConfig")
                    if (config.isNullOrBlank()) {
                        result.error("invalid", "ovpnConfig required", null)
                        return
                    }
                    val profile =
                        VpnProfile(
                            id = UUID.randomUUID().toString(),
                            name = name,
                            ovpnConfig = config,
                            username = call.argument("username"),
                            password = call.argument("password"),
                            appFilterMode = AppFilterMode.from(call.argument("appFilterMode")),
                            packageNames =
                                (call.argument<List<String>>("packageNames") ?: emptyList())
                                    .toMutableSet(),
                            isDefault = store.list().isEmpty(),
                        )
                    result.success(store.upsert(profile).toMap())
                }
                "updateProfile" -> {
                    @Suppress("UNCHECKED_CAST")
                    val map = call.arguments as? Map<String, Any?>
                    if (map == null) {
                        result.error("invalid", "profile map required", null)
                        return
                    }
                    val existing = store.get(map["id"] as String)
                    if (existing == null) {
                        result.error("not_found", "profile not found", null)
                        return
                    }
                    val updated = VpnProfile.fromMap(map)
                    result.success(store.upsert(updated).toMap())
                }
                "deleteProfile" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("invalid", "id required", null)
                        return
                    }
                    result.success(store.delete(id))
                }
                "setDefaultProfile" -> {
                    val id = call.argument<String>("id")
                    if (id == null) {
                        result.error("invalid", "id required", null)
                        return
                    }
                    result.success(store.setDefault(id)?.toMap())
                }
                "setSelectedProfile" -> {
                    val id = call.argument<String>("id")
                    store.setSelectedId(id)
                    result.success(true)
                }
                "getSelectedProfileId" -> result.success(store.getSelectedId())
                "updateAppFilter" -> {
                    val id = call.argument<String>("id")
                    val mode = AppFilterMode.from(call.argument("appFilterMode"))
                    val packages =
                        (call.argument<List<String>>("packageNames") ?: emptyList()).toMutableSet()
                    val profile = id?.let { store.get(it) }
                    if (profile == null) {
                        result.error("not_found", "profile not found", null)
                        return
                    }
                    profile.appFilterMode = mode
                    profile.packageNames = packages
                    result.success(store.upsert(profile).toMap())
                }
                "listInstalledApps" -> {
                    val icons = call.argument<Boolean>("includeIcons") ?: false
                    runInBackground(result) {
                        AppListHelper.listLaunchableApps(appContext, icons)
                    }
                }
                "getAppsByPackages" -> {
                    val packages = call.argument<List<String>>("packageNames") ?: emptyList()
                    runInBackground(result) {
                        AppListHelper.appsForPackages(appContext, packages)
                    }
                }
                "connect" -> connect(call.argument("profileId"), result)
                "disconnect" -> {
                    vpn.disconnect()
                    result.success(true)
                }
                "status" -> result.success(vpn.statusMap())
                "getLogs" -> result.success(store.readLogs(call.argument<Int>("limit") ?: 500))
                "clearLogs" -> {
                    store.clearLogs()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("error", e.message, e.stackTraceToString())
        }
    }

    private fun requestVpnPermission(result: Result) {
        val act = activity
        if (act == null) {
            result.error("no_activity", "Activity not attached", null)
            return
        }
        val intent = VpnService.prepare(act)
        if (intent != null) {
            pendingPermissionResult = result
            act.startActivityForResult(intent, REQ_VPN_PERMISSION)
        } else {
            result.success(true)
        }
    }

    private fun connect(
        profileId: String?,
        result: Result,
    ) {
        val act = activity
        if (act == null) {
            result.error("no_activity", "Activity not attached", null)
            return
        }
        val id = profileId ?: store.getSelectedId()
        val profile = id?.let { store.get(it) }
        if (profile == null) {
            result.error("not_found", "No profile selected", null)
            return
        }
        val intent = VpnService.prepare(act)
        if (intent != null) {
            pendingConnectResult = result
            pendingProfileId = profile.id
            act.startActivityForResult(intent, REQ_VPN_CONNECT)
            return
        }
        try {
            vpn.connect(profile)
            result.success(vpn.statusMap())
        } catch (e: Exception) {
            result.error("connect_failed", e.message, null)
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ): Boolean {
        when (requestCode) {
            REQ_VPN_PERMISSION -> {
                val ok = resultCode == Activity.RESULT_OK
                pendingPermissionResult?.success(ok)
                pendingPermissionResult = null
                return true
            }
            REQ_VPN_CONNECT -> {
                if (resultCode == Activity.RESULT_OK) {
                    val profile = pendingProfileId?.let { store.get(it) }
                    try {
                        if (profile != null) {
                            vpn.connect(profile)
                            pendingConnectResult?.success(vpn.statusMap())
                        } else {
                            pendingConnectResult?.error("not_found", "profile gone", null)
                        }
                    } catch (e: Exception) {
                        pendingConnectResult?.error("connect_failed", e.message, null)
                    }
                } else {
                    pendingConnectResult?.error("denied", "VPN permission denied", null)
                    stageSink?.success("denied")
                }
                pendingConnectResult = null
                pendingProfileId = null
                return true
            }
        }
        return false
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?,
    ) {
        stageSink = events
        vpn.ensureReceivers()
        stageSink?.success(vpn.currentStage())
    }

    override fun onCancel(arguments: Any?) {
        stageSink = null
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stageChannel.setStreamHandler(null)
        logChannel.setStreamHandler(null)
        vpn.dispose()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
        vpn.ensureReceivers()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }

    private fun runInBackground(
        result: Result,
        block: () -> Any?,
    ) {
        ioExecutor.execute {
            try {
                val value = block()
                mainHandler.post { result.success(value) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("error", e.message, e.stackTraceToString())
                }
            }
        }
    }

    companion object {
        private const val REQ_VPN_PERMISSION = 7711
        private const val REQ_VPN_CONNECT = 7712
    }
}
