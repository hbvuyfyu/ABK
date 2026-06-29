package com.gamevent.app

import android.app.ActivityManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.provider.Settings
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
                    "getDeviceIds" -> {
                        val pkgName = call.argument<String>("packageName") ?: ""
                        Thread {
                            val ids = getDeviceIds(pkgName)
                            runOnUiThread { result.success(ids) }
                        }.start()
                    }
                    "getGaid" -> {
                        Thread {
                            val gaid = readGaid()
                            runOnUiThread { result.success(gaid) }
                        }.start()
                    }
                    "getAfUid" -> {
                        val pkgName = call.argument<String>("packageName") ?: ""
                        Thread {
                            val afUid = readAfUid(pkgName)
                            runOnUiThread { result.success(afUid) }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── Device IDs (GAID + AF UID) ────────────────────────────────────────────

    private fun getDeviceIds(pkgName: String): Map<String, String> {
        val gaid  = readGaid()
        val afUid = if (pkgName.isNotEmpty()) readAfUid(pkgName) else ""
        return mapOf("gaid" to gaid, "afUid" to afUid)
    }

    /**
     * Reads the Google Advertising ID from device settings.
     * Works without root on Android 10+ via Settings.Secure.
     * Falls back to root-based extraction on older devices.
     */
    private fun readGaid(): String {
        // Method 1: Settings.Secure (works on most devices)
        try {
            val gaid = Settings.Secure.getString(contentResolver, "advertising_id")
            if (!gaid.isNullOrEmpty() && gaid != "00000000-0000-0000-0000-000000000000") {
                return gaid
            }
        } catch (_: Exception) {}

        // Method 2: Via root — read from GMS shared prefs
        try {
            val paths = listOf(
                "/data/data/com.google.android.gms/shared_prefs/adid_settings.xml",
                "/data/data/com.google.android.gms/shared_prefs/Checkin.xml"
            )
            for (path in paths) {
                val (out, _) = execSuOutput("cat '$path' 2>/dev/null", 5)
                val match = Regex("""<string name="adid_key">([^<]+)</string>""").find(out)
                    ?: Regex("""advertising_id[^>]*>([0-9a-f-]{36})""").find(out)
                val id = match?.groupValues?.getOrNull(1)?.trim() ?: ""
                if (id.length >= 36) return id
            }
        } catch (_: Exception) {}

        // Method 3: gsfid via root
        try {
            val (out, _) = execSuOutput(
                "content query --uri content://com.google.android.gsf.gservices/prefix --where \"name='android_id'\" 2>/dev/null | grep android_id",
                5
            )
            val id = out.trim().substringAfterLast("=").trim()
            if (id.isNotEmpty() && id != "null") return id
        } catch (_: Exception) {}

        return ""
    }

    /**
     * Tries to extract the AppsFlyer UID from the target app's data directory.
     * Requires root access. Reads appsflyer-data shared prefs file.
     */
    private fun readAfUid(pkgName: String): String {
        if (pkgName.isEmpty()) return ""

        val prefPaths = listOf(
            "/data/data/$pkgName/shared_prefs/appsflyer-data.xml",
            "/data/data/$pkgName/shared_prefs/appsflyer_data.xml",
            "/data/data/$pkgName/shared_prefs/AppsFlyerLib.xml",
            "/data/data/$pkgName/shared_prefs/com.appsflyer.OneLink.xml"
        )

        for (path in prefPaths) {
            try {
                val (out, _) = execSuOutput("cat '$path' 2>/dev/null", 5)
                if (out.isBlank()) continue

                // Try common key names for AF UID
                val patterns = listOf(
                    Regex("""<string name="appsflyer_id">([^<]+)</string>"""),
                    Regex("""<string name="AF_ID">([^<]+)</string>"""),
                    Regex("""<string name="appsflyer_device_id">([^<]+)</string>"""),
                    Regex("""<string name="afuid">([^<]+)</string>"""),
                    Regex("""([0-9]{10,13}-[0-9]{19,20})""")
                )
                for (pattern in patterns) {
                    val match = pattern.find(out)
                    val id = match?.groupValues?.getOrNull(1)?.trim() ?: ""
                    if (id.isNotEmpty() && id.length > 5) return id
                }
            } catch (_: Exception) {}
        }

        // Fallback: search all shared prefs for appsflyer ID pattern
        try {
            val (out, _) = execSuOutput(
                "grep -r 'appsflyer_id\\|AF_ID\\|afuid' /data/data/$pkgName/shared_prefs/ 2>/dev/null | head -5",
                5
            )
            val match = Regex("""([0-9]{10,13}-[0-9]{14,20})""").find(out)
            val id = match?.groupValues?.getOrNull(1)?.trim() ?: ""
            if (id.isNotEmpty()) return id
        } catch (_: Exception) {}

        return ""
    }

    // ─── Running Apps ──────────────────────────────────────────────────────────

    private fun getRunningApps(): List<Map<String, Any>> {
        val pm       = packageManager
        val apps     = mutableListOf<Map<String, Any>>()
        val seenPkgs = mutableSetOf<String>()
        val myPkg    = packageName
        val pidMap   = mutableMapOf<String, Int>()

        try {
            val am    = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val procs = am.runningAppProcesses ?: emptyList()
            for (proc in procs) {
                for (pkg in (proc.pkgList ?: emptyArray())) {
                    if (!pidMap.containsKey(pkg)) pidMap[pkg] = proc.pid
                }
            }
        } catch (_: Exception) {}

        try {
            val (psOut, _) = execSuOutput("ps -A", 5)
            for (line in psOut.lines()) {
                val parts = line.trim().split(Regex("\\s+"))
                if (parts.size < 2) continue
                val pid      = parts[1].toIntOrNull() ?: continue
                val procName = parts.last()
                if (procName.contains('.') && !procName.startsWith('/') && !procName.startsWith('[')) {
                    val pkg = procName.substringBefore(':')
                    if (!pidMap.containsKey(pkg)) pidMap[pkg] = pid
                }
            }
        } catch (_: Exception) {}

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
            val scriptFile = File(cacheDir, "jumper_07.js")
            scriptFile.writeText(JUMPER_SCRIPT)
            val scriptDest = "/data/local/tmp/jumper_07.js"
            execSuOutput("cp '${scriptFile.absolutePath}' $scriptDest && chmod 755 $scriptDest", 5)
            scriptFile.delete()

            val targetPid = if (pid > 0) pid else resolvePid(pkgName)
            if (targetPid <= 0) {
                return mapOf("success" to false,
                    "output" to "[-] لم يتم العثور على process لـ: $pkgName\n[*] تأكد أن التطبيق مفتوح.")
            }

            execSuOutput(
                "mkdir -p /data/local/tmp/oat/x86 /data/local/tmp/oat/x86_64 /data/local/tmp/oat/arm64 /data/local/tmp/oat/arm && " +
                "chmod -R 777 /data/local/tmp/oat 2>/dev/null; " +
                "chmod 1777 /data/local/tmp 2>/dev/null; " +
                "setenforce 0 2>/dev/null",
                5
            )

            val (binary, mode) = findFridaBinary()
                ?: return mapOf("success" to false, "output" to buildNotFoundMessage())

            val cmd = when (mode) {
                BinMode.INJECT_LOCAL -> "$binary --pid=$targetPid --script=$scriptDest --runtime=v8 --no-pause 2>&1"
                BinMode.INJECT_USB   -> "$binary -U --pid $targetPid -l $scriptDest --runtime=v8 --no-pause 2>&1"
                BinMode.FRIDA_LOCAL  -> "$binary -H 127.0.0.1:27042 --pid $targetPid -l $scriptDest --runtime=v8 --no-pause 2>&1"
                BinMode.FRIDA_USB    -> "$binary -U --pid $targetPid -l $scriptDest --runtime=v8 --no-pause 2>&1"
            }

            val (out, _) = execSuOutput(cmd, 60)

            if (out.contains("TIMEOUT")) {
                return mapOf("success" to false, "output" to out,
                    "error" to "Injection timed out. Try again.")
            }

            if (out.contains("Stream closed") || out.contains("closed") || out.contains("Connection")) {
                return mapOf("success" to false, "output" to out,
                    "error" to "Frida stream closed. Restart frida-server and try again.")
            }

            val success = out.contains("Event sent successfully") ||
                          out.contains("[+] Event sent") ||
                          out.contains("[+] Java runtime ready") ||
                          (out.contains("[+]") && out.contains("07-JUMPER"))

            if (!success && (out.contains("Stream closed") || out.contains("unable to find process"))) {
                val fallbackCmd = "frida -U -f $pkgName -l $scriptDest --runtime=v8 --no-pause 2>&1"
                val (fallbackOut, _) = execSuOutput(fallbackCmd, 60)
                val fallbackSuccess = fallbackOut.contains("Event sent successfully") ||
                                     fallbackOut.contains("[+] Event sent") ||
                                     fallbackOut.contains("[+] Java runtime ready")
                if (fallbackSuccess) {
                    return mapOf("success" to true, "output" to (out + "\n" + fallbackOut).trim())
                }
            }

            mapOf("success" to success, "output" to out.ifBlank { "[*] Script executed — no output." })
        } catch (e: Exception) {
            mapOf("success" to false, "output" to "[-] Exception: ${e.message}")
        }
    }

    private enum class BinMode { INJECT_LOCAL, INJECT_USB, FRIDA_LOCAL, FRIDA_USB }

    private fun findFridaBinary(): Pair<String, BinMode>? {
        val (findOut, _) = execSuOutput(
            "find /data/local/tmp /system/bin /system/xbin /data/adb " +
            "/sbin /vendor/bin /magisk -maxdepth 4 -name 'frida*' -type f 2>/dev/null",
            6
        )
        val foundPaths = findOut.lines().map { it.trim() }.filter { it.isNotEmpty() }

        val candidates = mutableListOf<Pair<String, BinMode>>()
        for (path in foundPaths) {
            when {
                path.contains("frida-inject") -> candidates.add(path to BinMode.INJECT_LOCAL)
                path.contains("frida-server") -> { }
                else -> {
                    candidates.add(path to BinMode.FRIDA_LOCAL)
                    candidates.add(path to BinMode.FRIDA_USB)
                }
            }
        }
        candidates.addAll(listOf(
            "frida-inject" to BinMode.INJECT_LOCAL,
            "frida"        to BinMode.FRIDA_LOCAL,
            "frida"        to BinMode.FRIDA_USB,
        ))

        for ((bin, mode) in candidates) {
            val (out, code) = execSuOutput("$bin --version 2>&1", 3)
            if (code == 0 || out.contains("frida", ignoreCase = true)) return bin to mode
        }
        return null
    }

    private fun buildNotFoundMessage(): String = """
[-] frida binary not found on this device.
[*] Fix: download frida-inject for your device arch and push it:
  1. Go to: https://github.com/frida/frida/releases
  2. Download: frida-inject-XX-android-arm64
  3. Push:
       adb push frida-inject /data/local/tmp/frida-inject
       adb shell su -c "chmod 755 /data/local/tmp/frida-inject"
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
            if (!completed) {
                p.destroyForcibly()
                return Pair("[-] TIMEOUT: Command exceeded ${timeoutSec}s", -1)
            }
            val stdout = p.inputStream.bufferedReader().readText()
            val stderr = p.errorStream.bufferedReader().readText()
            Pair((stdout + stderr).trim(), try { p.exitValue() } catch (_: Exception) { -1 })
        } catch (e: Exception) {
            Pair("[-] ${e.message}", -1)
        }
    }

    companion object {
        private val JUMPER_SCRIPT = """
rpc.exports = {
    ping: function() { return "alive"; }
};

function runJumper() {
    console.log("[*] 07-JUMPER initialising...");
    console.log("[*] Waiting for Java runtime...");

    Java.perform(function() {
        console.log("[+] Java runtime ready!");
        console.log("[+] Starting injection 07-JuMper script");

        try {
            var AppsFlyerLib = Java.use("com.appsflyer.AppsFlyerLib");
            var HashMap = Java.use("java.util.HashMap");
            var eventValues = HashMap.${"$"}new();
            eventValues.put("af", "level");
            var eventName = "power_5w";
            var ActivityThread = Java.use("android.app.ActivityThread");
            var context = ActivityThread.currentApplication().getApplicationContext();
            console.log("[+] Calling AppsFlyer:");
            console.log("  - Event Name: " + eventName);
            AppsFlyerLib.getInstance().logEvent(context, eventName, eventValues);
            console.log("[+] Event sent successfully!");
        } catch (e) {
            console.log("[-] Error: " + e.message);
            console.log("[-] Stack: " + e.stack);
        }
    });
}

setTimeout(runJumper, 2000);
setTimeout(function() {
    console.log("[*] Script timeout reached, exiting...");
}, 30000);
""".trimIndent()
    }
}
