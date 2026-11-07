package com.example.depenses

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {

    private var pendingPick: MethodChannel.Result? = null

    // Sélecteur de dossier d'Android (Storage Access Framework)
    private val treePicker = registerForActivityResult(
        ActivityResultContracts.OpenDocumentTree()
    ) { uri: Uri? ->
        val result = pendingPick
        pendingPick = null
        if (result != null) {
            if (uri == null) {
                result.success(null)
            } else {
                try {
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    result.success(
                        mapOf(
                            "uri" to uri.toString(),
                            "label" to DocumentsContract.getTreeDocumentId(uri)
                        )
                    )
                } catch (e: Exception) {
                    result.error("pick_error", e.message, null)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "depenses/backup")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "pickFolder" -> {
                            if (pendingPick != null) {
                                result.error("busy", "Sélection déjà en cours", null)
                            } else {
                                pendingPick = result
                                treePicker.launch(null)
                            }
                        }
                        "hasAllFilesAccess" -> result.success(hasAllFilesAccess())
                        "requestAllFilesAccess" -> {
                            requestAllFilesAccess()
                            result.success(null)
                        }
                        "save" -> {
                            val name = call.argument<String>("name")
                            val bytes = call.argument<ByteArray>("bytes")
                            val tree = call.argument<String>("tree")
                            result.success(
                                name != null && bytes != null && save(name, bytes, tree)
                            )
                        }
                        "delete" -> {
                            val name = call.argument<String>("name")
                            val tree = call.argument<String>("tree")
                            result.success(name != null && delete(name, tree))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("backup_error", e.message, null)
                }
            }
    }

    private fun save(name: String, bytes: ByteArray, tree: String?): Boolean =
        if (tree != null) saveToTree(name, bytes, tree) else saveToRoot(name, bytes)

    private fun delete(name: String, tree: String?): Boolean =
        if (tree != null) deleteFromTree(name, tree) else deleteFromRoot(name)

    // --- Dossier par défaut : /Depenses à la racine du stockage -----------

    private fun hasAllFilesAccess(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
                Environment.isExternalStorageManager()

    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                    Uri.parse("package:$packageName")
                )
            )
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
        }
    }

    private fun defaultDir(): File =
        File(Environment.getExternalStorageDirectory(), "Depenses")

    private fun saveToRoot(name: String, bytes: ByteArray): Boolean {
        if (!hasAllFilesAccess()) return false
        val dir = defaultDir()
        if (!dir.exists() && !dir.mkdirs()) return false
        File(dir, name).writeBytes(bytes)
        return true
    }

    private fun deleteFromRoot(name: String): Boolean {
        if (!hasAllFilesAccess()) return false
        val f = File(defaultDir(), name)
        return f.exists() && f.delete()
    }

    // --- Dossier choisi par l'utilisateur ---------------------------------

    private fun saveToTree(name: String, bytes: ByteArray, tree: String): Boolean {
        val treeUri = Uri.parse(tree)
        val parent = DocumentsContract.buildDocumentUriUsingTree(
            treeUri, DocumentsContract.getTreeDocumentId(treeUri)
        )
        val doc = DocumentsContract.createDocument(
            contentResolver, parent, "text/csv", name
        ) ?: return false
        val stream = contentResolver.openOutputStream(doc) ?: return false
        stream.use { it.write(bytes) }
        return true
    }

    private fun deleteFromTree(name: String, tree: String): Boolean {
        val treeUri = Uri.parse(tree)
        val parentId = DocumentsContract.getTreeDocumentId(treeUri)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME
        )
        val ids = mutableListOf<String>()
        contentResolver.query(children, columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                if (c.getString(1) == name) ids.add(c.getString(0))
            }
        }
        var deleted = false
        for (id in ids) {
            val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, id)
            if (DocumentsContract.deleteDocument(contentResolver, docUri)) deleted = true
        }
        return deleted
    }
}