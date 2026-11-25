plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
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
            // App Links open the app from this flavor's Hosting domain (#241).
            manifestPlaceholders["appLinkHost"] = "crewpoint-dev.web.app"
            // Email sign-in links come here (Firebase's default domain unless
            // the project has a custom one; functions/src/account/signInLink.ts).
            manifestPlaceholders["appLinkAuthHost"] = "crewpoint-dev.firebaseapp.com"
        }
        create("stg") {
            dimension = "environment"
            applicationId = "space.sookoon.crewpoint.stg"
            resValue("string", "app_name", "CrewPoint Stg")
            // App Links open the app from this flavor's Hosting domain (#241).
            manifestPlaceholders["appLinkHost"] = "crewpoint-stg.web.app"
            // Email sign-in links come here (Firebase's default domain unless
            // the project has a custom one; functions/src/account/signInLink.ts).
            manifestPlaceholders["appLinkAuthHost"] = "crewpoint-stg.firebaseapp.com"
        }
        create("prod") {
            dimension = "environment"
            applicationId = "space.sookoon.crewpoint.app"
            resValue("string", "app_name", "CrewPoint")
            // App Links open the app from this flavor's Hosting domain (#241).
            manifestPlaceholders["appLinkHost"] = "crewpoint.sookoon.space"
            // Email sign-in links come here (Firebase's default domain unless
            // the project has a custom one; functions/src/account/signInLink.ts).
            manifestPlaceholders["appLinkAuthHost"] = "crewpoint.sookoon.space"
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
