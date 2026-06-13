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
    compileSdk = 36
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
        minSdk = flutter.minSdkVersion
        targetSdk = 36
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
    // MediaPipe LLM Inference — Gemma 2B on-device (opzionale, scaricato dall'utente)
    implementation("com.google.mediapipe:tasks-genai:0.10.14")
    // OkHttp per il download del modello con autenticazione HuggingFace
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // Coroutines per integrare Task<T> di GMS con le coroutine Kotlin
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.1")
    // Activity Result API (registerForActivityResult) — richiesto da FlutterFragmentActivity
    implementation("androidx.activity:activity-ktx:1.9.3")
}

flutter {
    source = "../.."
}
