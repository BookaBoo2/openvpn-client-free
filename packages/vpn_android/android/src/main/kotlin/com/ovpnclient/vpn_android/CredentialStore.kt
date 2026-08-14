package com.ovpnclient.vpn_android

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Stores VPN usernames/passwords in EncryptedSharedPreferences (Android Keystore).
 */
class CredentialStore(context: Context) {
    private val prefs: SharedPreferences

    init {
        prefs =
            try {
                val masterKey =
                    MasterKey.Builder(context)
                        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                        .build()
                EncryptedSharedPreferences.create(
                    context,
                    "vpn_credentials",
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            } catch (_: Exception) {
                // Fallback if security-crypto fails on odd devices
                context.getSharedPreferences("vpn_credentials_fallback", Context.MODE_PRIVATE)
            }
    }

    fun save(
        profileId: String,
        username: String?,
        password: String?,
    ) {
        prefs.edit()
            .putString(userKey(profileId), username)
            .putString(passKey(profileId), password)
            .apply()
    }

    fun loadUsername(profileId: String): String? = prefs.getString(userKey(profileId), null)

    fun loadPassword(profileId: String): String? = prefs.getString(passKey(profileId), null)

    fun delete(profileId: String) {
        prefs.edit()
            .remove(userKey(profileId))
            .remove(passKey(profileId))
            .apply()
    }

    private fun userKey(id: String) = "u_$id"

    private fun passKey(id: String) = "p_$id"
}
