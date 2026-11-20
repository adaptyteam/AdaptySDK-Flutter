plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The activity that hosts Flutter: a fragment activity, as the plugin's platform views need, unless the Gradle
// property l2aActivity is "flutter" (a plain FlutterActivity, to which the plugin attaches without its views).
val hostActivity = providers.gradleProperty("l2aActivity").getOrElse("fragment")
require(hostActivity in setOf("fragment", "flutter")) { "l2aActivity is fragment or flutter, not $hostActivity" }

android {
    namespace = "com.adapty.flutter.adapty_l2a"
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
        // The app only hosts the plugin for integration tests and is never published.
        applicationId = "com.adapty.flutter.adapty_l2a"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/activity/$hostActivity/kotlin")
        }
    }

    buildTypes {
        release {
            // Never published: the debug keys are enough for a release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
