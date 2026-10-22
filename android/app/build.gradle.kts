plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.winsoftsc.passbook"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
                isCoreLibraryDesugaringEnabled = true

    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.winsoftsc.passbook"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: error("keyAlias missing in android/key.properties")
            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: error("keyPassword missing in android/key.properties")
            storePassword = keystoreProperties.getProperty("storePassword")
                ?: error("storePassword missing in android/key.properties")
            storeFile = rootProject.file("upload-keystore.jks").also { keystore ->
                if (!keystore.exists()) {
                    error("Release keystore not found at ${keystore.absolutePath}")
                }
            }
        }
    }

    buildTypes {
        release {
            if (!keystorePropertiesFile.exists()) {
                error(
                    "Release signing is not configured. Create android/key.properties " +
                        "and android/upload-keystore.jks before building for Play Store."
                )
            }
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// CHANGE #4: Add the dependencies block with the desugaring library
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}