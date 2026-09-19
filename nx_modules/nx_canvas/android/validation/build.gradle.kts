plugins {
    id("com.android.application")
    id("kotlin-android")
}
android {
    namespace = "com.nexus.nx_canvas.validation"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.nexus.nx_canvas.validation"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}
dependencies {
    implementation(project(":canvas-editor"))
    compileOnly(project(":vendor-api"))
    testImplementation("junit:junit:4.13.2")
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) } }
