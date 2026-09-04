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

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.garciaericn.parable_bloom"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
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
