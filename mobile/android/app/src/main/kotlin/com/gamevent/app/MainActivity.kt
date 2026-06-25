package com.gamevent.app

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.gamevent.app/jumper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getRunningApps" -> {
                        Thread {
                            val apps = getRunningApps()
                            runOnUiThread { result.success(apps) }
                        }.start()
                    }
                    "runJumper" -> {
                        val packageName = call.argument<String>("packageName") ?: ""
                        Thread {
                            val output = runJumperScript(packageName)
                            runOnUiThread { result.success(output) }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── Get Running Apps ─────────────────────────────────────────────────────

    private fun getRunningApps(): List<Map<String, Any>> {
        val pm = packageManager
        val result = mutableListOf<Map<String, Any>>()
        val seen = mutableSetOf<String>()
        val myPkg = packageName

        // Primary: ActivityManager running processes
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val procs = am.runningAppProcesses ?: emptyList()
            for (proc in procs) {
                for (pkg in (proc.pkgList ?: emptyArray())) {
                    if (pkg == myPkg || pkg in seen) continue
                    seen.add(pkg)
                    appEntry(pm, pkg, proc.importance)?.let { result.add(it) }
                }
            }
        } catch (_: Exception) {}

        // Fallback: root ps to catch any missed processes
        if (result.isEmpty()) {
            try {
                val ps = Runtime.getRuntime().exec(arrayOf("su", "-c", "ps -A"))
                ps.waitFor(5, TimeUnit.SECONDS)
                ps.inputStream.bufferedReader().forEachLine { line ->
                    val parts = line.trim().split(Regex("\\s+"))
                    val name = parts.lastOrNull() ?: return@forEachLine
                    if (name.contains('.') && !name.startsWith('-') && name !in seen && name != myPkg) {
                        seen.add(name)
                        appEntry(pm, name, 300)?.let { result.add(it) }
                    }
                }
            } catch (_: Exception) {}
        }

        return result.sortedBy { it["importance"] as Int }
    }

    private fun appEntry(pm: PackageManager, pkg: String, importance: Int): Map<String, Any>? {
        return try {
            val info: ApplicationInfo = pm.getApplicationInfo(pkg, 0)
            // Skip system apps with no visible UI
            if (info.flags and ApplicationInfo.FLAG_SYSTEM != 0 &&
                pm.getLaunchIntentForPackage(pkg) == null
            ) return null
            val name = pm.getApplicationLabel(info).toString()
            val icon = try { pm.getApplicationIcon(pkg) } catch (_: Exception) { null }
            val iconB64 = if (icon != null) drawableToBase64(icon) else ""
            mapOf("package" to pkg, "name" to name, "icon" to iconB64, "importance" to importance)
        } catch (_: Exception) { null }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val w = drawable.intrinsicWidth.coerceIn(1, 256)
        val h = drawable.intrinsicHeight.coerceIn(1, 256)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, w, h)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 70, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    // ─── Run Frida JuMper Script ───────────────────────────────────────────────

    private fun runJumperScript(packageName: String): Map<String, Any> {
        return try {
            // Write script to app cache, then copy to /data/local/tmp via root
            val scriptFile = File(cacheDir, "jumper_07.js")
            scriptFile.writeText(JUMPER_SCRIPT)

            val scriptDest = "/data/local/tmp/jumper_07.js"
            execSu("cp '${scriptFile.absolutePath}' $scriptDest && chmod 644 $scriptDest", 5)

            // Run frida — wait up to 12 seconds (script has 4s delay + execution time)
            val fridaCmd = "frida -U -n '$packageName' -l $scriptDest 2>&1"
            val (out, code) = execSuOutput(fridaCmd, 12)

            scriptFile.delete()

            val success = out.contains("[+] Event sent successfully") ||
                    out.contains("Event sent successfully")
            mapOf("success" to success, "output" to out.ifBlank { "[*] Script executed, no output captured." })
        } catch (e: Exception) {
            mapOf("success" to false, "output" to "[-] Error: ${e.message}")
        }
    }

    private fun execSu(cmd: String, timeoutSec: Long) {
        try {
            val p = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
            p.waitFor(timeoutSec, TimeUnit.SECONDS)
        } catch (_: Exception) {}
    }

    private fun execSuOutput(cmd: String, timeoutSec: Long): Pair<String, Int> {
        return try {
            val p = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
            val completed = p.waitFor(timeoutSec, TimeUnit.SECONDS)
            if (!completed) p.destroyForcibly()
            val out = p.inputStream.bufferedReader().readText() +
                      p.errorStream.bufferedReader().readText()
            Pair(out.trim(), if (completed) p.exitValue() else -1)
        } catch (e: Exception) {
            Pair("[-] ${e.message}", -1)
        }
    }

    // ─── Embedded Frida Script ─────────────────────────────────────────────────

    companion object {
        private val JUMPER_SCRIPT = """
setTimeout(function() {
    Java.perform(function() {
        console.log("\n[+] Starting injection 07-JuMper script");

        var AppsFlyerLib = Java.use("com.appsflyer.AppsFlyerLib");

        var HashMap = Java.use("java.util.HashMap");
        var eventValues = HashMap.${'$'}new();
        eventValues.put("af", "level");

        var eventName = "power_5w";

        var ActivityThread = Java.use("android.app.ActivityThread");
        var context = ActivityThread.currentApplication().getApplicationContext();

        console.log("[+] Calling AppsFlyer:");
        console.log("  - Event Name: " + eventName);
        console.log("  - Event Values: " + JSON.stringify({ af_level: "af_level" }));

        try {
            AppsFlyerLib.getInstance().logEvent(
                context,
                eventName,
                eventValues
            );
            console.log("[+] Event sent successfully!");
        } catch (e) {
            console.log("[-] Error calling logEvent: " + e.message);
        }
    });
}, 4000);

console.log("[*] 07-JUMPER ..");
""".trimIndent()
    }
}
