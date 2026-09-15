allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
    if (project.name == "opus_flutter_android") {
        afterEvaluate {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                // Current NDKs require API 21; the app already targets a higher minimum.
                defaultConfig.minSdk = 21
                compileSdk = project(":app").extensions
                    .getByType<com.android.build.api.dsl.ApplicationExtension>().compileSdk
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
