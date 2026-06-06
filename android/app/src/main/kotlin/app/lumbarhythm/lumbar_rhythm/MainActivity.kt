package app.lumbarhythm.lumbar_rhythm

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val galleryChannel = "lumbar_rhythm/gallery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            galleryChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePngToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName")

                    if (bytes == null || fileName.isNullOrBlank()) {
                        result.error("invalid_args", "Missing image bytes or file name.", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = savePngToGallery(bytes, fileName)
                        result.success(mapOf("saved" to (uri != null), "uri" to uri?.toString()))
                    } catch (error: Exception) {
                        result.error("save_failed", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePngToGallery(bytes: ByteArray, fileName: String): android.net.Uri? {
        val resolver = applicationContext.contentResolver
        val imageCollection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Lumbar Rhythm")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val uri = resolver.insert(imageCollection, values) ?: return null

        resolver.openOutputStream(uri)?.use { output ->
            output.write(bytes)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }

        return uri
    }
}
