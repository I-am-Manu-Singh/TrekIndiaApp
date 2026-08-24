# Flutter Proguard & R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Play Store split install & deferred components
-dontwarn com.google.android.play.core.**

# Keep models and serialized classes
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Supabase / Postgrest / GoTrue / Storage / Realtime
-dontwarn io.github.jan.supabase.**
-keep class io.github.jan.supabase.** { *; }

# Third-party library warnings suppression
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
-dontwarn com.google.crypto.tink.**
-dontwarn com.google.android.gms.**
-dontwarn okhttp3.**
-dontwarn okio.**
