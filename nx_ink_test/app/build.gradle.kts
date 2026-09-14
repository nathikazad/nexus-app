plugins { id("com.android.application") }
android {
    namespace = "com.nexus.inktest"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.nexus.inktest"
        minSdk = 30
        targetSdk = 36
        versionCode = 1
        versionName = "0.1"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    buildTypes {
        release {
            isDebuggable = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
