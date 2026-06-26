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
                        val pid     = call.argument<Int>("pid") ?: -1
                        val pkgName = call.argument<String>("packageName") ?: ""
                        Thread {
                            val output = runJumperScript(pid, pkgName)
                            runOnUiThread { result.success(output) }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── Running Apps ──────────────────────────────────────────────────────────

    private fun getRunningApps(): List<Map<String, Any>> {
        val pm       = packageManager
        val apps     = mutableListOf<Map<String, Any>>()
        val seenPkgs = mutableSetOf<String>()
        val myPkg    = packageName
        val pidMap   = mutableMapOf<String, Int>() // package -> pid

        // 1. ActivityManager (gives real PIDs)
        try {
            val am    = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val procs = am.runningAppProcesses ?: emptyList()
            for (proc in procs) {
                for (pkg in (proc.pkgList ?: emptyArray())) {
                    if (!pidMap.containsKey(pkg)) pidMap[pkg] = proc.pid
                }
            }
        } catch (_: Exception) {}

        // 2. Root ps -A fallback
        try {
            val (psOut, _) = execSuOutput("ps -A", 5)
            for (line in psOut.lines()) {
                val parts = line.trim().split(Regex("\\s+"))
                if (parts.size < 2) continue
                val pid      = parts[1].toIntOrNull() ?: continue
                val procName = parts.last()
                if (procName.contains('.') &&
                    !procName.startsWith('/') &&
                    !procName.startsWith('[')
                ) {
                    val pkg = procName.substringBefore(':')
                    if (!pidMap.containsKey(pkg)) pidMap[pkg] = pid
                }
            }
        } catch (_: Exception) {}

        // 3. Build entries
        for ((pkg, pid) in pidMap) {
            if (pkg == myPkg || pkg in seenPkgs) continue
            seenPkgs.add(pkg)
            buildAppEntry(pm, pkg, pid)?.let { apps.add(it) }
        }

        return apps.sortedBy { it["name"] as String }
    }

    private fun buildAppEntry(pm: PackageManager, pkg: String, pid: Int): Map<String, Any>? {
        return try {
            val info = pm.getApplicationInfo(pkg, 0)
            if (info.flags and ApplicationInfo.FLAG_SYSTEM != 0 &&
                pm.getLaunchIntentForPackage(pkg) == null) return null
            val name    = pm.getApplicationLabel(info).toString()
            val icon    = try { pm.getApplicationIcon(pkg) } catch (_: Exception) { null }
            val iconB64 = if (icon != null) drawableToBase64(icon) else ""
            mapOf("package" to pkg, "name" to name, "icon" to iconB64, "pid" to pid, "importance" to 100)
        } catch (_: Exception) { null }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val w      = drawable.intrinsicWidth.coerceIn(1, 192)
        val h      = drawable.intrinsicHeight.coerceIn(1, 192)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, w, h)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 70, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    // ─── Frida Injection ───────────────────────────────────────────────────────

    private fun runJumperScript(pid: Int, pkgName: String): Map<String, Any> {
        return try {
            // Write script file
            val scriptFile = File(cacheDir, "jumper_07.js")
            scriptFile.writeText(JUMPER_SCRIPT)
            val scriptDest = "/data/local/tmp/jumper_07.js"
            execSuOutput("cp '${scriptFile.absolutePath}' $scriptDest && chmod 755 $scriptDest", 5)
            scriptFile.delete()

            // Resolve PID if needed
            val targetPid = if (pid > 0) pid else resolvePid(pkgName)
            if (targetPid <= 0) {
                return mapOf("success" to false,
                    "output" to "[-] لم يتم العثور على process لـ: $pkgName\n[*] تأكد أن التطبيق مفتوح.")
            }

            // Find a working frida binary
            val (binary, mode) = findFridaBinary()
                ?: return mapOf("success" to false,
                    "output" to buildNotFoundMessage())

            // Build command based on detected binary type
            val cmd = when (mode) {
                BinMode.INJECT_LOCAL  -> "$binary --pid=$targetPid --script=$scriptDest 2>&1"
                BinMode.INJECT_USB    -> "$binary -U --pid $targetPid -l $scriptDest 2>&1"
                BinMode.FRIDA_LOCAL   -> "$binary -H 127.0.0.1:27042 --pid $targetPid -l $scriptDest 2>&1"
                BinMode.FRIDA_USB     -> "$binary -U --pid $targetPid -l $scriptDest 2>&1"
            }

            val (out, _) = execSuOutput(cmd, 14)
            val success  = out.contains("Event sent successfully") || out.contains("[+]")
            mapOf("success" to success, "output" to out.ifBlank { "[*] Script executed — no output." })
        } catch (e: Exception) {
            mapOf("success" to false, "output" to "[-] Exception: ${e.message}")
        }
    }

    // ─── Binary Detection ──────────────────────────────────────────────────────

    private enum class BinMode { INJECT_LOCAL, INJECT_USB, FRIDA_LOCAL, FRIDA_USB }

    /**
     * Searches common locations for frida-inject or frida binaries.
     * Priority: frida-inject (device-side) > frida -H localhost > frida -U
     */
    private fun findFridaBinary(): Pair<String, BinMode>? {
        // First: find frida binaries anywhere on device
        val (findOut, _) = execSuOutput(
            "find /data/local/tmp /system/bin /system/xbin /data/adb " +
            "/sbin /vendor/bin /magisk -maxdepth 4 -name 'frida*' -type f 2>/dev/null",
            6
        )
        val foundPaths = findOut.lines().map { it.trim() }.filter { it.isNotEmpty() }

        // Also add PATH-resolved candidates
        val candidates = mutableListOf<Pair<String, BinMode>>()
        for (path in foundPaths) {
            when {
                path.contains("frida-inject") -> candidates.add(path to BinMode.INJECT_LOCAL)
                path.contains("frida-server") -> { /* skip server binary */ }
                else -> {
                    candidates.add(path to BinMode.FRIDA_LOCAL)
                    candidates.add(path to BinMode.FRIDA_USB)
                }
            }
        }
        // Add well-known names via PATH
        candidates.addAll(listOf(
            "frida-inject" to BinMode.INJECT_LOCAL,
            "frida"        to BinMode.FRIDA_LOCAL,
            "frida"        to BinMode.FRIDA_USB,
        ))

        for ((bin, mode) in candidates) {
            val testCmd = when (mode) {
                BinMode.INJECT_LOCAL -> "$bin --version 2>&1"
                BinMode.INJECT_USB   -> "$bin --version 2>&1"
                BinMode.FRIDA_LOCAL  -> "$bin --version 2>&1"
                BinMode.FRIDA_USB    -> "$bin --version 2>&1"
            }
            val (out, code) = execSuOutput(testCmd, 3)
            if (code == 0 || out.contains("frida", ignoreCase = true)) {
                return bin to mode
            }
        }
        return null
    }

    private fun buildNotFoundMessage(): String = """
[-] frida binary not found on this device.

[!] frida-server is running but you also need frida-inject.

[*] Fix: download frida-inject for your device arch and push it:

  1. Go to: https://github.com/frida/frida/releases
  2. Download: frida-inject-XX-android-arm64  (or x86 for emulator)
  3. Push to device:
       adb push frida-inject /data/local/tmp/frida-inject
       adb shell su -c "chmod 755 /data/local/tmp/frida-inject"

[*] Then restart the app and try again.
""".trimIndent()

    private fun resolvePid(pkgName: String): Int {
        val (pidOut, _) = execSuOutput("pidof '$pkgName' 2>/dev/null | awk '{print \$1}'", 4)
        pidOut.trim().toIntOrNull()?.let { if (it > 0) return it }
        val (psOut, _) = execSuOutput("ps -A 2>/dev/null | grep '$pkgName' | head -1", 4)
        return psOut.trim().split(Regex("\\s+")).getOrNull(1)?.toIntOrNull() ?: -1
    }

    private fun execSuOutput(cmd: String, timeoutSec: Long): Pair<String, Int> {
        return try {
            val p         = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
            val completed = p.waitFor(timeoutSec, TimeUnit.SECONDS)
            if (!completed) p.destroyForcibly()
            val stdout = p.inputStream.bufferedReader().readText()
            val stderr = p.errorStream.bufferedReader().readText()
            Pair((stdout + stderr).trim(), if (completed) try { p.exitValue() } catch (_: Exception) { -1 } else -1)
        } catch (e: Exception) {
            Pair("[-] ${e.message}", -1)
        }
    }

    // ─── Embedded Script ───────────────────────────────────────────────────────

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
        console.log("  - Event Values: " + JSON.stringify({ af: "level" }));

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
