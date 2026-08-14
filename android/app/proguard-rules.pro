# Missing annotation stubs from Tink / EncryptedSharedPreferences
-dontwarn com.google.errorprone.annotations.CanIgnoreReturnValue
-dontwarn com.google.errorprone.annotations.CheckReturnValue
-dontwarn com.google.errorprone.annotations.Immutable
-dontwarn com.google.errorprone.annotations.RestrictedApi
-dontwarn javax.annotation.Nullable
-dontwarn javax.annotation.concurrent.GuardedBy

# OpenVPN / ics-openvpn engine
-keep class de.blinkt.openvpn.** { *; }
-keep class org.spongycastle.** { *; }
-dontwarn de.blinkt.openvpn.**
-dontwarn org.spongycastle.**
