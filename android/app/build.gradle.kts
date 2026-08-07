plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun computeVersionCode(vName: String?, fallback: Int): Int {
    if (vName.isNullOrEmpty()) return fallback
    val clean = vName.split("+")[0].trim()
    val parts = clean.split(".")
    if (parts.size >= 3) {
        val major = parts[0].toIntOrNull() ?: 0
        val minor = parts[1].toIntOrNull() ?: 0
        val patch = parts[2].toIntOrNull() ?: 0
        val calculated = major * 10000 + minor * 100 + patch
        return if (calculated > fallback) calculated else fallback
    }
    return fallback
}

android {
    namespace = "com.krajtilak.nummo"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.krajtilak.nummo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionName = flutter.versionName
        versionCode = computeVersionCode(flutter.versionName, flutter.versionCode)
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") ?: System.getenv("KEY_ALIAS") ?: "nummo_key"
            keyPassword = keystoreProperties.getProperty("keyPassword") ?: System.getenv("KEY_PASSWORD") ?: "nummo_release_pass"
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) } ?: System.getenv("STORE_FILE")?.let { file(it) } ?: file("nummo-release.jks")
            storePassword = keystoreProperties.getProperty("storePassword") ?: System.getenv("STORE_PASSWORD") ?: "nummo_release_pass"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
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
