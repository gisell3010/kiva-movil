plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}
android {
    namespace = "com.kiva.kiva"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    val projectNdk = file("../../.tooling/android-sdk/ndk/28.2.13676358")
    if (projectNdk.isDirectory) {
        ndkPath = projectNdk.absolutePath
        project.extensions.extraProperties.set("flutter.installedNdkVersions", flutter.ndkVersion)
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.kiva.mobile"
        minSdk = maxOf(23, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release {
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