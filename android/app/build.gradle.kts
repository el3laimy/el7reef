import java.io.FileInputStream
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

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val localDebugKeystoreFile = rootProject.file("app/debug-el7reef-v2.keystore")
val requestedReleaseBuild = gradle.startParameter.taskNames.any {
    it.lowercase().contains("release")
}

fun releaseKeystoreProperty(name: String): String {
    val value = keystoreProperties[name] as String?
    if (value.isNullOrBlank()) {
        throw GradleException(
            "Missing '$name' in android/key.properties. " +
                "Release builds must use the real release keystore."
        )
    }
    return value
}

fun releaseKeystoreFile(): java.io.File {
    val storeFile = file(releaseKeystoreProperty("storeFile"))
    if (!storeFile.exists()) {
        throw GradleException(
            "Release keystore file does not exist: ${storeFile.path}. " +
                "Update 'storeFile' in android/key.properties before building release artifacts."
        )
    }
    if (storeFile.canonicalFile == localDebugKeystoreFile.canonicalFile) {
        throw GradleException(
            "Release builds must not use android/app/debug-el7reef-v2.keystore. " +
                "Create a separate Play Store release keystore and register its SHA-1/SHA-256 in Firebase."
        )
    }
    return storeFile
}

android {
    namespace = "com.el7reef.app"
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
        applicationId = "com.el7reef.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("el7reefDebug") {
            if (localDebugKeystoreFile.exists()) {
                keyAlias = "el7reefdebugv2"
                keyPassword = "android"
                storeFile = localDebugKeystoreFile
                storePassword = "android"
            }
        }
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = releaseKeystoreProperty("keyAlias")
                keyPassword = releaseKeystoreProperty("keyPassword")
                storeFile = releaseKeystoreFile()
                storePassword = releaseKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            if (localDebugKeystoreFile.exists()) {
                signingConfig = signingConfigs.getByName("el7reefDebug")
            }
        }
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (requestedReleaseBuild) {
                throw GradleException(
                    "Release signing is not configured. Create android/key.properties " +
                        "and a release keystore before building release artifacts."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.media3:media3-common:1.9.2")
    implementation("androidx.media3:media3-effect:1.9.2")
    implementation("androidx.media3:media3-transformer:1.9.2")

    androidTestImplementation("androidx.test:core:1.7.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
