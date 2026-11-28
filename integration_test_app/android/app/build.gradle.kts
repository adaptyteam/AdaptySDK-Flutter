plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The activity that hosts Flutter: a fragment activity, as the plugin's platform views need, unless the Gradle
// property l2aActivity is "flutter" (a plain FlutterActivity, where the flow view of the plugin only reports the
// activity it needs).
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
            kotlin.srcDir("src/activity/$hostActivity/kotlin")
        }
    }

    buildTypes {
        release {
            // Never published: the debug keys are enough for a release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
