package com.ovpnclient.vpn_android

import org.junit.Assert.assertEquals
import org.junit.Test

class VpnAndroidPluginTest {
    @Test
    fun appFilterModeWire() {
        assertEquals(AppFilterMode.WHITELIST, AppFilterMode.from("whitelist"))
        assertEquals(AppFilterMode.BLACKLIST, AppFilterMode.from("blacklist"))
        assertEquals("all", AppFilterMode.ALL.wire())
    }

    @Test
    fun profileMapRoundTrip() {
        val profile =
            VpnProfile(
                id = "1",
                name = "Home",
                ovpnConfig = "client",
                appFilterMode = AppFilterMode.BLACKLIST,
                packageNames = mutableSetOf("com.example"),
            )
        val restored = VpnProfile.fromMap(profile.toMap())
        assertEquals("Home", restored.name)
        assertEquals(AppFilterMode.BLACKLIST, restored.appFilterMode)
        assertEquals(setOf("com.example"), restored.packageNames)
    }
}
