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
                        val pid = call.argument<Int>("pid") ?: -1
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

    // ─── Get Running Apps with real PIDs ──────────────────────────────────────

    private fun getRunningApps(): List<Map<String, Any>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, Any>>()
        val seenPkgs = mutableSetOf<String>()
        val myPkg = packageName

        // Step 1: Use ActivityManager to get running processes + their PIDs
        val pidMap = mutableMapOf<String, Int>() // package -> pid
        try {
            val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val procs = am.runningAppProcesses ?: emptyList()
            for (proc in procs) {
                val pid = proc.pid
                for (pkg in (proc.pkgList ?: emptyArray())) {
                    if (!pidMap.containsKey(pkg)) pidMap[pkg] = pid
                }
            }
        } catch (_: Exception) {}

        // Step 2: Also parse `ps -A` via root to catch hidden/background processes
        try {
            val ps = Runtime.getRuntime().exec(arrayOf("su", "-c", "ps -A"))
            ps.waitFor(5, TimeUnit.SECONDS)
            ps.inputStream.bufferedReader().forEachLine { line ->
                // Format: USER PID PPID VSZ RSS WCHAN ADDR S NAME
                val parts = line.trim().split(Regex("\\s+"))
                if (parts.size >= 9) {
                    val pid = parts[1].toIntOrNull() ?: return@forEachLine
                    val procName = parts.last()
                    // Only consider valid package names (contain dot, no special chars)
                    if (procName.contains('.') &&
                        !procName.startsWith('/') &&
                        !procName.startsWith('[') &&
                        procName == procName.filter { it.isLetterOrDigit() || it == '.' || it == '_' || it == ':' }
                    ) {
                        // Strip process suffix e.g. com.game:bg -> com.game
                        val pkg = procName.substringBefore(':')
                        if (!pidMap.containsKey(pkg)) pidMap[pkg] = pid
                    }
                }
            }
        } catch (_: Exception) {}

        // Step 3: Build the app list with names, icons, and PIDs
        for ((pkg, pid) in pidMap) {
            if (pkg == myPkg || pkg in seenPkgs) continue
            seenPkgs.add(pkg)
            val entry = buildAppEntry(pm, pkg, pid) ?: continue
            apps.add(entry)
        }

        // Sort: foreground apps first (lower PID order from ActivityManager = more recent)
        return apps.sortedWith(compareBy({ -(it["importance"] as Int) }, { it["name"] as String }))
    }

    private fun buildAppEntry(pm: PackageManager, pkg: String, pid: Int): Map<String, Any>? {
        return try {
            val info: ApplicationInfo = pm.getApplicationInfo(pkg, 0)
            // Skip system-only apps with no launcher icon
            if (info.flags and ApplicationInfo.FLAG_SYSTEM != 0 &&
                pm.getLaunchIntentForPackage(pkg) == null
            ) return null
            val name = pm.getApplicationLabel(info).toString()
            val icon = try { pm.getApplicationIcon(pkg) } catch (_: Exception) { null }
            val iconB64 = if (icon != null) drawableToBase64(icon) else ""
            mapOf(
                "package"    to pkg,
                "name"       to name,
                "icon"       to iconB64,
                "pid"        to pid,
                "importance" to 100  // value for sorting
            )
        } catch (_: Exception) { null }
    }

    private fun drawableToBase64(drawable: Drawable): String {
        val w = drawable.intrinsicWidth.coerceIn(1, 192)
        val h = drawable.intrinsicHeight.coerceIn(1, 192)
        val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, w, h)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 70, out)
        return Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
    }

    // ─── Inject Frida script by PID (most reliable method) ────────────────────

    private fun runJumperScript(pid: Int, pkgName: String): Map<String, Any> {
        return try {
            // 1. Write JS script to app cache dir (always accessible)
            val scriptFile = File(cacheDir, "jumper_07.js")
            scriptFile.writeText(JUMPER_SCRIPT)

            // 2. Copy to /data/local/tmp which frida-server can read
            val scriptDest = "/data/local/tmp/jumper_07.js"
            val copyResult = execSuOutput(
                "cp '${scriptFile.absolutePath}' $scriptDest && chmod 644 $scriptDest",
                5
            )
            if (copyResult.second != 0 && !copyResult.first.isBlank()) {
                // Non-critical: frida might still work from cache path
            }

            // 3. Resolve the real PID to inject into
            //    If we have a valid PID from ActivityManager, use it directly.
            //    Otherwise fall back to looking up PID via `pidof` or `ps`.
            val targetPid: Int = when {
                pid > 0 -> pid
                else -> resolvePid(pkgName)
            }

            if (targetPid <= 0) {
                scriptFile.delete()
                return mapOf(
                    "success" to false,
                    "output"  to "[-] Could not find running process for: $pkgName\n[*] Make sure the app is open and in the foreground."
                )
            }

            // 4. Inject via PID — this is the correct, reliable way
            val fridaCmd = "frida -U --pid $targetPid -l $scriptDest 2>&1"
            val (out, _) = execSuOutput(fridaCmd, 14)

            scriptFile.delete()

            val success = out.contains("[+] Event sent successfully") ||
                          out.contains("Event sent successfully!")
            mapOf(
                "success" to success,
                "output"  to out.ifBlank { "[*] No output — script executed silently." }
            )
        } catch (e: Exception) {
            mapOf("success" to false, "output" to "[-] Exception: ${e.message}")
        }
    }

    /** Look up PID of a package via root shell commands */
    private fun resolvePid(pkgName: String): Int {
        // Try pidof (available on most rooted devices)
        var (out, _) = execSuOutput("pidof '$pkgName' 2>/dev/null | awk '{print $1}'", 4)
        out.trim().toIntOrNull()?.let { if (it > 0) return it }

        // Fallback: grep ps output
        val (psOut, _) = execSuOutput("ps -A 2>/dev/null | grep '$pkgName' | head -1", 4)
        val parts = psOut.trim().split(Regex("\\s+"))
        return parts.getOrNull(1)?.toIntOrNull() ?: -1
    }

    private fun execSuOutput(cmd: String, timeoutSec: Long): Pair<String, Int> {
        return try {
            val p = Runtime.getRuntime().exec(arrayOf("su", "-c", cmd))
            val completed = p.waitFor(timeoutSec, TimeUnit.SECONDS)
            if (!completed) p.destroyForcibly()
            val stdout = p.inputStream.bufferedReader().readText()
            val stderr = p.errorStream.bufferedReader().readText()
            val combined = (stdout + stderr).trim()
            Pair(combined, if (completed) try { p.exitValue() } catch (_: Exception) { -1 } else -1)
        } catch (e: Exception) {
            Pair("[-] ${e.message}", -1)
        }
    }

    // ─── Frida Script (embedded) ───────────────────────────────────────────────

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
