plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.danieledituri.esami_tracker"
    // Fissiamo a 35 per avere le API Android 14 disponibili a compile time
    // (anche se AICore viene attivato solo a runtime sui dispositivi supportati).
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.danieledituri.esami_tracker"
        // flutter_secure_storage richiede API 23+.
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing con le chiavi debug per ora; sostituire con chiavi di
            // produzione prima del rilascio sul Play Store.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // ML Kit Document Scanner — interfaccia fotocamera per scansione documenti
    implementation("com.google.android.gms:play-services-mlkit-document-scanner:16.0.0-beta1")
    // ML Kit Text Recognition — OCR on-device (modello scaricato via GMS)
    implementation("com.google.android.gms:play-services-mlkit-text-recognition:19.0.1")
    // Gemini Nano via AICore — richiede Android 14+ e Pixel 8/9 series
    implementation("com.google.ai.edge.aicore:aicore:0.0.1-exp.1")
    // Coroutines per integrare Task<T> di GMS con le coroutine Kotlin
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
}

flutter {
    source = "../.."
}
