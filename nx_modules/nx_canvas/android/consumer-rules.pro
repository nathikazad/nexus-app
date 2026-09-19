# These classes are provided by the tablet boot class path, not packaged stubs.
-dontwarn com.xrz.**
-keep class com.nexus.nx_canvas.RecordingNoteView { *; }

# Keep local freeze traces readable in this diagnostic build.
-keepnames class com.nexus.nx_canvas.**
-keepclassmembernames class com.nexus.nx_canvas.** { *; }
-keepattributes SourceFile,LineNumberTable
