plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "space.sookoon.crewpoint_app"
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
        applicationId = "space.sookoon.crewpoint.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "space.sookoon.crewpoint.dev"
            resValue("string", "app_name", "CrewPoint Dev")
        }
        create("stg") {
            dimension = "environment"
            applicationId = "space.sookoon.crewpoint.stg"
            resValue("string", "app_name", "CrewPoint Stg")
        }
        create("prod") {
            dimension = "environment"
            applicationId = "space.sookoon.crewpoint.app"
            resValue("string", "app_name", "CrewPoint")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
