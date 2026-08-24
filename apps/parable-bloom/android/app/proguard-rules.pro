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
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# JNI & Native methods
-keepclasseswithmembernames class * {
    native <methods>;
}
