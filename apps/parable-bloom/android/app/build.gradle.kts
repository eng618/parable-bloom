plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.garciaericn.parable_bloom"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.garciaericn.parable_bloom"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // sentry_flutter 10.x (pubspec allows ^10.1.0) requires minSdk 26, while
        // Flutter 3.x defaults minSdkVersion to 24. Override so the release
        // manifest merger does not fail.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = System.getenv("ANDROID_KEYSTORE_PATH")?.let { file(it) }
            storePassword = System.getenv("ANDROID_STORE_PASSWORD")
            keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // Fail fast: never ship a release signed with debug keys.
            // CI (publish.yml) provides these via Bitwarden; see
            // documentation/how-to/release-process.md for local setup.
            signingConfig = signingConfigs.getByName("release")
            // R8 minify + resource shrinking. Flutter 3.47's Gradle plugin
            // also turns these on for release unless -Pshrink=false (deferred
            // components only). Set them here so the app file is the source
            // of truth and a raw Gradle release cannot ship unshrunk.
            // This block is evaluated after the Flutter plugin's apply().
            val shrink = (project.findProperty("shrink") as? String)?.toBoolean() ?: true
            isMinifyEnabled = shrink
            isShrinkResources = shrink
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Fail fast when assembling a release without signing credentials.
// This check runs only when a release task is actually in the task graph,
// so debug builds and configuration-time inspection are unaffected.
gradle.taskGraph.whenReady {
    val releaseTasks = setOf("bundleRelease", "assembleRelease")
    if (allTasks.any { it.name in releaseTasks }) {
        val requiredEnv = listOf(
            "ANDROID_KEYSTORE_PATH",
            "ANDROID_STORE_PASSWORD",
            "ANDROID_KEY_ALIAS",
            "ANDROID_KEY_PASSWORD"
        )
        val missing = requiredEnv.filter { System.getenv(it).isNullOrEmpty() }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "Release signing credentials missing: ${missing.joinToString()}. " +
                    "Set them in the environment (CI provides them via Bitwarden) — " +
                    "refusing to build a release that would fall back to debug keys."
            )
        }
        val keystore = file(System.getenv("ANDROID_KEYSTORE_PATH"))
        if (!keystore.exists()) {
            throw GradleException(
                "ANDROID_KEYSTORE_PATH does not exist: ${keystore.path}"
            )
        }
    }
}

flutter {
    source = "../.."
}
