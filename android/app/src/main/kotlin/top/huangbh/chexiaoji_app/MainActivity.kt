package top.huangbh.chexiaoji_app

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private companion object {
        const val UPDATE_CHANNEL = "chexiaoji/app_update"
        const val FILE_PROVIDER_SUFFIX = ".fileprovider"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInstalledVersion" -> result.success(installedVersion())
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        val sha256 = call.argument<String>("sha256")
                        if (path.isNullOrBlank() || sha256.isNullOrBlank()) {
                            result.error("invalid_arguments", "缺少安装包路径或校验值", null)
                            return@setMethodCallHandler
                        }
                        installApk(File(path), sha256, result)
                    }
                    "openInstallPermissionSettings" -> {
                        openInstallPermissionSettings()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun installedVersion(): Map<String, Any> {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
        } else {
            packageManager.getPackageInfo(packageName, 0)
        }
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.longVersionCode
        } else {
            packageInfo.versionCode.toLong()
        }
        return mapOf(
            "versionName" to (packageInfo.versionName ?: "0.0.0"),
            "versionCode" to versionCode,
        )
    }

    private fun installApk(file: File, expectedSha256: String, result: MethodChannel.Result) {
        if (!file.exists()) {
            result.error("missing_file", "安装包不存在，请重新下载", null)
            return
        }

        val apkFile = try {
            file.canonicalFile
        } catch (error: Exception) {
            result.error("invalid_path", "安装包路径不合法", null)
            return
        }
        val cacheRoot = cacheDir.canonicalFile
        if (!apkFile.path.startsWith(cacheRoot.path + File.separator)) {
            result.error("invalid_path", "安装包路径不合法", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !packageManager.canRequestPackageInstalls()
        ) {
            result.success("permission_required")
            return
        }

        Thread {
            val actualSha256 = try {
                sha256(apkFile)
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("hash_failed", "校验安装包失败，请重新下载", null)
                }
                return@Thread
            }
            if (!actualSha256.equals(expectedSha256, ignoreCase = true)) {
                runOnUiThread {
                    result.error("hash_mismatch", "安装包校验失败，请重新下载", null)
                }
                return@Thread
            }

            runOnUiThread {
                try {
                    val uri = FileProvider.getUriForFile(
                        this,
                        packageName + FILE_PROVIDER_SUFFIX,
                        apkFile,
                    )
                    val intent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, "application/vnd.android.package-archive")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success("started")
                } catch (error: Exception) {
                    result.error(
                        "install_failed",
                        error.message ?: "无法打开系统安装程序",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            startActivity(intent)
        }
    }

    private fun sha256(file: File): String {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            while (true) {
                val read = input.read(buffer)
                if (read <= 0) break
                digest.update(buffer, 0, read)
            }
        }
        return digest.digest().joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }
}
