import java.util.Properties

plugins { id("java-library") }
java { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
val props = Properties().apply { rootProject.file("local.properties").inputStream().use { load(it) } }
dependencies { compileOnly(files("${props.getProperty("sdk.dir")}/platforms/android-36/android.jar")) }
