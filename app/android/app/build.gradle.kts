import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.koshkikode.vetviona"
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
        applicationId = "com.koshkikode.vetviona"

        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Pinned (not flutter.minSdkVersion): the secure-storage, QR-scanner and
        // NFC plugins require API 24+, and CI must not have to patch this file.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing: provide android/key.properties (gitignored) with
    // storeFile, storePassword, keyAlias, keyPassword. Without it the release
    // build falls back to debug keys, which must never be distributed.
    val keyProps = Properties()
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) keyPropsFile.inputStream().use { keyProps.load(it) }

    signingConfigs {
        if (keyPropsFile.exists()) {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keyPropsFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "WARNING: android/key.properties not found - signing the " +
                        "release build with the DEBUG key. Never distribute this build."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// Tagged CI releases set REQUIRE_RELEASE_SIGNING=true so a debug-signed
// APK/AAB can never be produced by accident.
gradle.taskGraph.whenReady {
    val buildingRelease = allTasks.any { task ->
        val name = task.name
        (name.startsWith("assemble") || name.startsWith("bundle") || name.startsWith("package")) &&
            name.endsWith("Release")
    }
    val requireSigning = System.getenv("REQUIRE_RELEASE_SIGNING") == "true"
    if (buildingRelease && requireSigning && !rootProject.file("key.properties").exists()) {
        throw GradleException(
            "REQUIRE_RELEASE_SIGNING=true but android/key.properties is missing; " +
                "refusing to sign a release build with the debug key."
        )
    }
}
