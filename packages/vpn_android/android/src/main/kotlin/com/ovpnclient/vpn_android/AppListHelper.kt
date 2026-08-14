package com.ovpnclient.vpn_android

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.util.Base64
import java.io.ByteArrayOutputStream

object AppListHelper {
    fun listLaunchableApps(
        context: Context,
        includeIcons: Boolean = false,
    ): List<Map<String, Any?>> {
        val pm = context.packageManager
        val intent =
            android.content.Intent(android.content.Intent.ACTION_MAIN, null).apply {
                addCategory(android.content.Intent.CATEGORY_LAUNCHER)
            }
        val resolveInfos = pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        val seen = HashSet<String>()
        val result = mutableListOf<Map<String, Any?>>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo.packageName
            if (!seen.add(pkg)) continue
            if (pkg == context.packageName) continue
            val appInfo =
                try {
                    pm.getApplicationInfo(pkg, 0)
                } catch (_: PackageManager.NameNotFoundException) {
                    continue
                }
            val label = pm.getApplicationLabel(appInfo).toString()
            val map =
                mutableMapOf<String, Any?>(
                    "packageName" to pkg,
                    "label" to label,
                    "systemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                )
            if (includeIcons) {
                try {
                    val icon = pm.getApplicationIcon(appInfo)
                    map["iconBase64"] = drawableToBase64(icon)
                } catch (_: Exception) {
                    map["iconBase64"] = null
                }
            }
            result.add(map)
        }
        return result.sortedBy { (it["label"] as String).lowercase() }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val bitmap =
            when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val w = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                    val h = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            }
        val scaled = Bitmap.createScaledBitmap(bitmap, 96, 96, true)
        val out = ByteArrayOutputStream()
        scaled.compress(Bitmap.CompressFormat.PNG, 85, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }
}
