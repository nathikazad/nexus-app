plugins { id("com.android.library"); id("kotlin-android") }
android {
    namespace = "com.nexus.nx_canvas.recovery"
    compileSdk = 36
    defaultConfig { minSdk = 24 }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_11; targetCompatibility = JavaVersion.VERSION_11 }
}
dependencies {
    api(project(":canvas-model"))
    api(project(":canvas-engine"))
    testImplementation("junit:junit:4.13.2")
}

kotlin { compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11) } }
