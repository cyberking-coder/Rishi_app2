# Keep rules for R8/ProGuard so shrinking doesn't strip classes the
# Flutter engine and native plugins reach via reflection / JNI.

# --- Flutter engine -------------------------------------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# --- just_audio / audio_service (ExoPlayer / Media3) ----------------------
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.ryanheise.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn androidx.media3.**

# --- Keep annotations & native method signatures --------------------------
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Kotlin metadata (avoids reflection breakage) -------------------------
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
