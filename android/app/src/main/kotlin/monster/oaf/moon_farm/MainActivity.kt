package monster.oaf.moon_farm

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "monster.oaf.moon_farm/launcher"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchUrl" -> {
                        val url = call.argument<String>("url")
                        if (url != null) {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(true)
                        } else {
                            result.error("INVALID_URL", "URL is null", null)
                        }
                    }
                    "writeToDownloads" -> {
                        val fileName = call.argument<String>("fileName")
                        val content = call.argument<String>("content")
                        if (fileName == null || content == null) {
                            result.error("INVALID_ARGS", "fileName and content required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val values = ContentValues().apply {
                                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                                put(MediaStore.Downloads.MIME_TYPE, "application/json")
                                put(MediaStore.Downloads.IS_PENDING, 1)
                            }
                            val uri = contentResolver.insert(
                                MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                            )!!
                            contentResolver.openOutputStream(uri)?.use { stream ->
                                stream.write(content.toByteArray(Charsets.UTF_8))
                            }
                            values.clear()
                            values.put(MediaStore.Downloads.IS_PENDING, 0)
                            contentResolver.update(uri, values, null, null)
                            result.success(fileName)
                        } catch (e: Exception) {
                            result.error("WRITE_FAILED", e.message, null)
                        }
                    }
                    "listMoonfarmDownloads" -> {
                        // Returns a list of maps: [{name, uri}] for any
                        // moonfarm_*.json file in the Downloads collection.
                        try {
                            val projection = arrayOf(
                                MediaStore.Downloads._ID,
                                MediaStore.Downloads.DISPLAY_NAME,
                            )
                            val selection = "${MediaStore.Downloads.DISPLAY_NAME} LIKE ?"
                            val selectionArgs = arrayOf("moonfarm_%.json")
                            val cursor = contentResolver.query(
                                MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                                projection, selection, selectionArgs,
                                "${MediaStore.Downloads.DATE_MODIFIED} DESC"
                            )
                            val files = mutableListOf<Map<String, String>>()
                            cursor?.use {
                                val idCol = it.getColumnIndexOrThrow(MediaStore.Downloads._ID)
                                val nameCol = it.getColumnIndexOrThrow(MediaStore.Downloads.DISPLAY_NAME)
                                while (it.moveToNext()) {
                                    val id = it.getLong(idCol)
                                    val name = it.getString(nameCol)
                                    val uri = Uri.withAppendedPath(
                                        MediaStore.Downloads.EXTERNAL_CONTENT_URI, id.toString()
                                    ).toString()
                                    files.add(mapOf("name" to name, "uri" to uri))
                                }
                            }
                            result.success(files)
                        } catch (e: Exception) {
                            result.error("LIST_FAILED", e.message, null)
                        }
                    }
                    "readDownloadsFile" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("INVALID_ARGS", "uri required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val content = contentResolver
                                .openInputStream(Uri.parse(uri))
                                ?.bufferedReader()
                                ?.use { it.readText() }
                                ?: throw Exception("Could not open file")
                            result.success(content)
                        } catch (e: Exception) {
                            result.error("READ_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
