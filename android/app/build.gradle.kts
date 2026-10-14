import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps SDK key: `MAPS_API_KEY` in the (untracked) android/local.properties,
// or the MAPS_API_KEY environment variable on build machines. Never commit it.
val mapsApiKey: String = run {
    val properties = Properties()
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { properties.load(it) }
    properties.getProperty("MAPS_API_KEY") ?: System.getenv("MAPS_API_KEY") ?: ""
}

// Upload-key signing for store builds: android/key.properties (untracked; see
// docs/releases_and_updates.md) with storeFile, storePassword, keyAlias and
// keyPassword. Never commit the keystore or its passwords.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasUploadKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "app.myglo.myglo"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.myglo.myglo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    signingConfigs {
        if (hasUploadKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties, local release runs (`flutter run --release`)
            // fall back to the debug key; store bundles are refused below.
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "release" else "debug")
        }
    }
}

// A Play Store bundle (what `shorebird release android` builds) must never be
// debug-signed: fail early instead of registering an unusable release.
gradle.taskGraph.whenReady {
    if (!hasUploadKey && allTasks.any { it.name == "bundleRelease" }) {
        throw GradleException(
            "Release bundle needs the upload key: create android/key.properties " +
                "(see docs/releases_and_updates.md).",
        )
    }
}

flutter {
    source = "../.."
}
