package com.nexus.nx_notes

import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.android.RenderMode

class MainActivity : AudioServiceFragmentActivity() {
    // This host frequently hands off to the tablet's native handwriting surface.
    // Texture mode avoids SurfaceView teardown blocking the main looper for seconds
    // on this device. Live ink still uses the vendor's independent native surface.
    override fun getRenderMode(): RenderMode = RenderMode.texture
}
