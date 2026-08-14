package com.ovpnclient.vpn_android

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

enum class AppFilterMode {
    ALL,
    WHITELIST,
    BLACKLIST;

    companion object {
        fun from(value: String?): AppFilterMode =
            when (value?.lowercase()) {
                "whitelist" -> WHITELIST
                "blacklist" -> BLACKLIST
                else -> ALL
            }
    }

    fun wire(): String =
        when (this) {
            ALL -> "all"
            WHITELIST -> "whitelist"
            BLACKLIST -> "blacklist"
        }
}

data class VpnProfile(
    val id: String,
    var name: String,
    var ovpnConfig: String,
    var appFilterMode: AppFilterMode = AppFilterMode.ALL,
    var packageNames: MutableSet<String> = mutableSetOf(),
    var username: String? = null,
    var password: String? = null,
    var createdAt: Long = System.currentTimeMillis(),
    var lastUsedAt: Long? = null,
    var isDefault: Boolean = false,
) {
    fun toMap(): Map<String, Any?> =
        mapOf(
            "id" to id,
            "name" to name,
            "ovpnConfig" to ovpnConfig,
            "appFilterMode" to appFilterMode.wire(),
            "packageNames" to packageNames.toList(),
            "username" to username,
            "password" to password,
            "createdAt" to createdAt,
            "lastUsedAt" to lastUsedAt,
            "isDefault" to isDefault,
        )

    /** Persist without secrets in the JSON blob; secrets go to CredentialStore. */
    fun toJsonPublic(): JSONObject =
        JSONObject().apply {
            put("id", id)
            put("name", name)
            put("ovpnConfig", ovpnConfig)
            put("appFilterMode", appFilterMode.wire())
            put("packageNames", JSONArray(packageNames.toList()))
            put("createdAt", createdAt)
            put("lastUsedAt", lastUsedAt ?: JSONObject.NULL)
            put("isDefault", isDefault)
        }

    fun toJson(): JSONObject = toJsonPublic()

    companion object {
        fun fromJson(obj: JSONObject): VpnProfile {
            val packages = mutableSetOf<String>()
            val arr = obj.optJSONArray("packageNames")
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    packages.add(arr.getString(i))
                }
            }
            val username = if (obj.has("username") && !obj.isNull("username")) {
                obj.getString("username").ifEmpty { null }
            } else {
                null
            }
            val password = if (obj.has("password") && !obj.isNull("password")) {
                obj.getString("password").ifEmpty { null }
            } else {
                null
            }
            return VpnProfile(
                id = obj.getString("id"),
                name = obj.getString("name"),
                ovpnConfig = obj.getString("ovpnConfig"),
                appFilterMode = AppFilterMode.from(obj.optString("appFilterMode")),
                packageNames = packages,
                username = username,
                password = password,
                createdAt = obj.optLong("createdAt", System.currentTimeMillis()),
                lastUsedAt = if (obj.isNull("lastUsedAt")) null else obj.optLong("lastUsedAt"),
                isDefault = obj.optBoolean("isDefault", false),
            )
        }

        fun fromMap(map: Map<String, Any?>): VpnProfile {
            @Suppress("UNCHECKED_CAST")
            val packages =
                ((map["packageNames"] as? List<*>)?.mapNotNull { it as? String } ?: emptyList())
                    .toMutableSet()
            return VpnProfile(
                id = map["id"] as? String ?: UUID.randomUUID().toString(),
                name = map["name"] as? String ?: "Profile",
                ovpnConfig = map["ovpnConfig"] as? String ?: "",
                appFilterMode = AppFilterMode.from(map["appFilterMode"] as? String),
                packageNames = packages,
                username = map["username"] as? String,
                password = map["password"] as? String,
                createdAt = (map["createdAt"] as? Number)?.toLong() ?: System.currentTimeMillis(),
                lastUsedAt = (map["lastUsedAt"] as? Number)?.toLong(),
                isDefault = map["isDefault"] as? Boolean ?: false,
            )
        }
    }
}

class ProfileStore(
    context: Context,
) {
    private val file = File(context.filesDir, "vpn_profiles.json")
    private val prefs = context.getSharedPreferences("vpn_prefs", Context.MODE_PRIVATE)
    private val credentials = CredentialStore(context)

    fun list(): List<VpnProfile> {
        if (!file.exists()) return emptyList()
        val root = JSONObject(file.readText())
        val arr = root.optJSONArray("profiles") ?: return emptyList()
        val out = mutableListOf<VpnProfile>()
        for (i in 0 until arr.length()) {
            val profile = VpnProfile.fromJson(arr.getJSONObject(i))
            profile.username = credentials.loadUsername(profile.id) ?: profile.username
            profile.password = credentials.loadPassword(profile.id) ?: profile.password
            out.add(profile)
        }
        return out.sortedByDescending { it.lastUsedAt ?: it.createdAt }
    }

    fun get(id: String): VpnProfile? = list().firstOrNull { it.id == id }

    fun saveAll(profiles: List<VpnProfile>) {
        val arr = JSONArray()
        profiles.forEach {
            credentials.save(it.id, it.username, it.password)
            arr.put(it.toJsonPublic())
        }
        file.writeText(JSONObject().put("profiles", arr).toString())
    }

    fun upsert(profile: VpnProfile): VpnProfile {
        val profiles = list().toMutableList()
        val idx = profiles.indexOfFirst { it.id == profile.id }
        if (profile.isDefault) {
            profiles.forEachIndexed { i, p -> profiles[i] = p.copy(isDefault = false) }
        }
        if (idx >= 0) {
            profiles[idx] = profile
        } else {
            profiles.add(profile)
        }
        saveAll(profiles)
        return profile
    }

    fun delete(id: String): Boolean {
        val profiles = list().toMutableList()
        val removed = profiles.removeAll { it.id == id }
        if (removed) {
            credentials.delete(id)
            saveAll(profiles)
        }
        return removed
    }

    fun setDefault(id: String): VpnProfile? {
        val profiles = list().map { it.copy(isDefault = it.id == id) }
        saveAll(profiles)
        return profiles.firstOrNull { it.id == id }
    }

    fun getDefaultId(): String? = prefs.getString("default_profile_id", null) ?: list().firstOrNull { it.isDefault }?.id

    fun setSelectedId(id: String?) {
        prefs.edit().putString("selected_profile_id", id).apply()
    }

    fun getSelectedId(): String? = prefs.getString("selected_profile_id", null) ?: getDefaultId()

    fun appendLog(line: String) {
        val logs = File(file.parentFile, "vpn_logs.txt")
        logs.appendText("${System.currentTimeMillis()}\t$line\n")
        // Keep last ~200KB
        if (logs.length() > 200_000) {
            val text = logs.readText()
            logs.writeText(text.takeLast(100_000))
        }
    }

    fun readLogs(limit: Int = 500): List<String> {
        val logs = File(file.parentFile, "vpn_logs.txt")
        if (!logs.exists()) return emptyList()
        return logs.readLines().takeLast(limit)
    }

    fun clearLogs() {
        File(file.parentFile, "vpn_logs.txt").delete()
    }
}
