package com.ovpnclient.vpn_android

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import de.blinkt.openvpn.VpnProfile
import de.blinkt.openvpn.core.ConfigParser
import de.blinkt.openvpn.core.OpenVPNService
import de.blinkt.openvpn.core.OpenVPNThread
import de.blinkt.openvpn.core.ProfileManager
import de.blinkt.openvpn.core.VPNLaunchHelper
import de.blinkt.openvpn.core.VpnStatus
import java.io.StringReader

/**
 * Launches OpenVPN via ics-openvpn-based library and applies per-app filter
 * (whitelist / blacklist) on the VpnProfile before establish().
 */
class OpenVpnController(
    private val context: Context,
    private val store: ProfileStore,
) {
    interface Listener {
        fun onStage(stage: String)

        fun onStats(
            duration: String,
            byteIn: String,
            byteOut: String,
            lastPacketReceive: String,
        )

        fun onLog(line: String)
    }

    var listener: Listener? = null
    var currentProfileId: String? = null
        private set

    private var receiverRegistered = false

    private val receiver =
        object : BroadcastReceiver() {
            override fun onReceive(
                ctx: Context?,
                intent: Intent?,
            ) {
                if (intent == null) return
                val state = intent.getStringExtra("state")
                if (state != null) {
                    val mapped = mapStage(state)
                    store.appendLog("stage=$mapped raw=$state")
                    listener?.onStage(mapped)
                    listener?.onLog("[$mapped] $state")
                }
                val duration = intent.getStringExtra("duration") ?: "00:00:00"
                val lastPacket = intent.getStringExtra("lastPacketReceive") ?: "0"
                val byteIn = intent.getStringExtra("byteIn") ?: "0"
                val byteOut = intent.getStringExtra("byteOut") ?: "0"
                listener?.onStats(duration, byteIn, byteOut, lastPacket)
            }
        }

    fun ensureReceivers() {
        if (receiverRegistered) return
        VpnStatus.initLogCache(context.cacheDir)
        LocalBroadcastManager.getInstance(context).registerReceiver(
            receiver,
            IntentFilter("connectionState"),
        )
        receiverRegistered = true
    }

    fun dispose() {
        if (receiverRegistered) {
            LocalBroadcastManager.getInstance(context).unregisterReceiver(receiver)
            receiverRegistered = false
        }
    }

    fun prepareVpnPermission(activity: Activity): Intent? = VpnService.prepare(activity)

    fun connect(profile: com.ovpnclient.vpn_android.VpnProfile) {
        ensureReceivers()
        currentProfileId = profile.id
        store.appendLog("connect profile=${profile.name} mode=${profile.appFilterMode.wire()}")
        listener?.onStage("connecting")
        listener?.onLog("Connecting ${profile.name}…")

        val cp = ConfigParser()
        try {
            cp.parseConfig(StringReader(profile.ovpnConfig))
            val vp: VpnProfile = cp.convertProfile()
            vp.mName = profile.name
            vp.mProfileCreator = context.packageName
            if (!profile.username.isNullOrEmpty()) {
                vp.mUsername = profile.username
            }
            if (!profile.password.isNullOrEmpty()) {
                vp.mPassword = profile.password
            }

            applyAppFilter(vp, profile)

            val check = vp.checkProfile(context)
            if (check != de.blinkt.openvpn.R.string.no_error_found) {
                val msg = context.getString(check)
                store.appendLog("profile_error=$msg")
                listener?.onStage("error")
                listener?.onLog("Profile error: $msg")
                throw IllegalArgumentException(msg)
            }

            ProfileManager.setTemporaryProfile(context, vp)
            VPNLaunchHelper.startOpenVpn(vp, context)

            val updated = profile.copy(lastUsedAt = System.currentTimeMillis())
            store.upsert(updated)
            store.setSelectedId(profile.id)
        } catch (e: ConfigParser.ConfigParseError) {
            store.appendLog("parse_error=${e.message}")
            listener?.onStage("error")
            listener?.onLog("Parse error: ${e.message}")
            throw e
        } catch (e: Exception) {
            store.appendLog("connect_error=${e.message}")
            listener?.onStage("error")
            listener?.onLog("Connect error: ${e.message}")
            throw e
        }
    }

    private fun applyAppFilter(
        vp: VpnProfile,
        profile: com.ovpnclient.vpn_android.VpnProfile,
    ) {
        vp.mAllowedAppsVpn.clear()
        when (profile.appFilterMode) {
            AppFilterMode.ALL -> {
                vp.mAllowedAppsVpnAreDisallowed = true
                vp.mAllowAppVpnBypass = false
            }
            AppFilterMode.BLACKLIST -> {
                // Default in library: disallowed list
                vp.mAllowedAppsVpnAreDisallowed = true
                vp.mAllowAppVpnBypass = false
                vp.mAllowedAppsVpn.addAll(profile.packageNames.filter { isInstalled(it) })
            }
            AppFilterMode.WHITELIST -> {
                vp.mAllowedAppsVpnAreDisallowed = false
                vp.mAllowAppVpnBypass = false
                val allowed = profile.packageNames.filter { isInstalled(it) }.toMutableSet()
                // Keep VPN app itself able to manage the tunnel
                allowed.add(context.packageName)
                vp.mAllowedAppsVpn.addAll(allowed)
            }
        }
        Log.i(
            TAG,
            "appFilter mode=${profile.appFilterMode} apps=${vp.mAllowedAppsVpn} disallowed=${vp.mAllowedAppsVpnAreDisallowed}",
        )
    }

    private fun isInstalled(packageName: String): Boolean =
        try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: Exception) {
            false
        }

    fun disconnect() {
        store.appendLog("disconnect")
        listener?.onStage("disconnecting")
        try {
            OpenVPNThread.stop()
        } catch (e: Exception) {
            store.appendLog("disconnect_error=${e.message}")
        }
        listener?.onStage("disconnected")
        currentProfileId = null
    }

    fun currentStage(): String {
        val status = OpenVPNService.getStatus()
        return if (status.isNullOrBlank()) "disconnected" else mapStage(status)
    }

    fun statusMap(): Map<String, Any?> =
        mapOf(
            "stage" to currentStage(),
            "profileId" to currentProfileId,
            "rawStatus" to (OpenVPNService.getStatus() ?: ""),
        )

    companion object {
        private const val TAG = "OpenVpnController"

        fun mapStage(raw: String): String =
            when (raw.uppercase()) {
                "CONNECTED" -> "connected"
                "DISCONNECTED" -> "disconnected"
                "WAIT" -> "wait_connection"
                "AUTH" -> "authenticating"
                "RECONNECTING" -> "reconnect"
                "NONETWORK" -> "no_connection"
                "CONNECTING" -> "connecting"
                "PREPARE" -> "prepare"
                "DENIED" -> "denied"
                "ERROR" -> "error"
                "EXITING" -> "exiting"
                "ASSIGN_IP" -> "assign_ip"
                "ADD_ROUTES" -> "add_routes"
                "GET_CONFIG" -> "get_config"
                "TCP_CONNECT" -> "tcp_connect"
                "UDP_CONNECT" -> "udp_connect"
                "RESOLVE" -> "resolve"
                else -> raw.lowercase()
            }
    }
}
