# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google & Firebase
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
# Play Core (Flutter engine references splitcompat/splitinstall/tasks for
# PlayStoreDeferredComponentManager / FlutterPlayStoreSplitApplication, but the
# app does not use deferred components; suppress R8 missing-class errors).
-dontwarn com.google.android.play.core.**
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# JNI & Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
