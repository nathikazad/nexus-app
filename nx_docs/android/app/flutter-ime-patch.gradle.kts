import org.gradle.api.artifacts.transform.*
import org.gradle.api.attributes.Attribute
import org.gradle.api.file.FileSystemLocation
import org.gradle.api.provider.Provider
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import java.util.zip.ZipEntry

// Replace only the pinned embedding callback with our source-compatible lifecycle patch.
abstract class StripFlutterImeCallback : TransformAction<TransformParameters.None> {
    @get:InputArtifact
    @get:PathSensitive(PathSensitivity.NAME_ONLY)
    abstract val inputArtifact: Provider<FileSystemLocation>
    override fun transform(outputs: TransformOutputs) {
        val input = inputArtifact.get().asFile
        if (!input.name.startsWith("flutter_embedding_")) {
            outputs.file(input)
            return
        }
        check(input.name.contains("a10d8ac38de835021c8d2f920dbf50a920ccc030")) {
            "Rebase the NX IME lifecycle patch before upgrading the Flutter embedding: ${input.name}"
        }
        val prefix = "io/flutter/plugin/editing/ImeSyncDeferringInsetsCallback"
        var removed = 0
        ZipFile(input).use { zip ->
            ZipOutputStream(outputs.file(input.name).outputStream()).use { out ->
                zip.entries().asSequence().forEach { entry ->
                    if (entry.name == "$prefix.class" || entry.name.startsWith("$prefix\$")) {
                        removed++
                    } else {
                        out.putNextEntry(ZipEntry(entry.name).apply { time = 0 })
                        if (!entry.isDirectory) zip.getInputStream(entry).use { it.copyTo(out) }
                        out.closeEntry()
                    }
                }
            }
        }
        check(removed >= 4) { "Flutter IME callback classes were not found in ${input.name}" }
    }
}
val patched = Attribute.of("com.nexus.flutter-ime-patched", Boolean::class.javaObjectType)
val artifactType = Attribute.of("artifactType", String::class.java)
dependencies {
    attributesSchema { attribute(patched) }
    artifactTypes.getByName("jar") { attributes.attribute(patched, false) }
    registerTransform(StripFlutterImeCallback::class.java) {
        from.attribute(patched, false).attribute(artifactType, "jar")
        to.attribute(patched, true).attribute(artifactType, "jar")
    }
}
configurations.configureEach {
    if (name.endsWith("CompileClasspath") || name.endsWith("RuntimeClasspath")) {
        attributes.attribute(patched, true)
    }
}
