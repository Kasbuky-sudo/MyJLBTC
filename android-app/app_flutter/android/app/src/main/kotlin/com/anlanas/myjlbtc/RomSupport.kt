package com.anlanas.myjlbtc

import android.os.Build
import android.util.Log

/**
 * 判断本机系统对「灵动岛 / 实时通知」的支持情况。
 *
 * 各家 OEM 在 Android 16 上都有自己的岛：ColorOS 流体云、HyperOS 超级岛、MagicOS 灵动胶囊……
 * 它们都吃 AOSP 16 的 Live Updates（`Notification.ProgressStyle` + 推广常驻通知），
 * 但各家从哪个大版本开始接、以及三星的实现节奏不同，所以这里按品牌 + ROM 版本号给个结论。
 *
 * 已知接入情况（用户 2026-10-08 提供）：
 * - OPPO / 一加 / realme：ColorOS 17
 * - 小米 / 红米：HyperOS 3
 * - 荣耀：MagicOS 10
 * - 三星：One UI 8
 */
object RomSupport {

    private const val TAG = "MyJLBTC-Rom"

    /** 适配结论 */
    enum class Verdict { SUPPORTED, LOW_VERSION, UNTESTED }

    data class RomInfo(
        val brand: String,
        val romName: String,
        val version: String,
        val verdict: Verdict,
        /** 需要的版本描述，用于提示语（如「HyperOS 4」） */
        val required: String,
    )

    /** 系统属性（读不到返回空串；第三方 ROM 上这些属性往往不存在） */
    private fun prop(key: String): String = try {
        val clazz = Class.forName("android.os.SystemProperties")
        val get = clazz.getMethod("get", String::class.java, String::class.java)
        (get.invoke(null, key, "") as? String)?.trim().orEmpty()
    } catch (e: Exception) {
        ""
    }

    /** 取版本号里的第一个数字段：`OS4.0.2` → 4；`V17.0.1` → 17；`MagicOS 10.0` → 10 */
    private fun major(version: String): Int? =
        Regex("(\\d+)").find(version)?.groupValues?.get(1)?.toIntOrNull()

    private fun info(): RomInfo {
        val manufacturer = Build.MANUFACTURER.orEmpty()
        val brandRaw = Build.BRAND.orEmpty()
        val haystack = "$manufacturer $brandRaw".lowercase()

        // 小米 / 红米 / POCO：HyperOS 用 ro.mi.os.version.name（OS1.0/OS4.0…），MIUI 用 ro.miui.ui.version.name
        if (haystack.contains("xiaomi") || haystack.contains("redmi") || haystack.contains("poco")) {
            val hyper = prop("ro.mi.os.version.name")
            val miui = prop("ro.miui.ui.version.name")
            val version = hyper.ifEmpty { miui.ifEmpty { prop("ro.build.version.incremental") } }
            val majorVersion = major(hyper.ifEmpty { miui })
            val verdict = when {
                majorVersion == null -> Verdict.UNTESTED // 第三方 ROM（属性被刷掉）
                hyper.isEmpty() -> Verdict.LOW_VERSION // 还是 MIUI
                majorVersion >= 3 -> Verdict.SUPPORTED // HyperOS 3 起已接入（真机确认）
                else -> Verdict.LOW_VERSION
            }
            val name = when {
                hyper.isNotEmpty() -> "HyperOS"
                miui.isNotEmpty() -> "MIUI"
                else -> "非原厂 ROM"
            }
            return RomInfo("小米", name, version, verdict, "HyperOS 3")
        }

        // OPPO / 一加 / realme：ColorOS 用 ro.build.version.oplusrom / ro.oppo.version
        if (haystack.contains("oppo") || haystack.contains("oneplus") || haystack.contains("realme")) {
            val oplus = prop("ro.build.version.oplusrom")
            val coloros = prop("ro.oppo.version").ifEmpty { prop("ro.build.version.opporom") }
            val version = coloros.ifEmpty { oplus.ifEmpty { prop("ro.build.version.incremental") } }
            val majorVersion = major(coloros.ifEmpty { oplus })
            val verdict = when {
                majorVersion == null -> Verdict.UNTESTED
                majorVersion >= 17 -> Verdict.SUPPORTED
                else -> Verdict.LOW_VERSION
            }
            return RomInfo("OPPO 系", "ColorOS", version, verdict, "ColorOS 17")
        }

        // 荣耀：MagicOS 用 ro.build.version.magic
        if (haystack.contains("honor") || haystack.contains("hihonor")) {
            val magic = prop("ro.build.version.magic")
            val majorVersion = major(magic)
            val verdict = when {
                majorVersion == null -> Verdict.UNTESTED
                majorVersion >= 10 -> Verdict.SUPPORTED
                else -> Verdict.LOW_VERSION
            }
            return RomInfo("荣耀", "MagicOS", magic, verdict, "MagicOS 10")
        }

        // 三星：One UI 8 起接入灵动岛；版本号看 ro.build.version.oneui（如 80000 = One UI 8.0）
        if (haystack.contains("samsung")) {
            val oneUi = prop("ro.build.version.oneui")
            val majorVersion = oneUi.toIntOrNull()?.let { it / 10000 }
                ?: major(oneUi)
            val verdict = when {
                majorVersion == null -> Verdict.UNTESTED
                majorVersion >= 8 -> Verdict.SUPPORTED
                else -> Verdict.LOW_VERSION
            }
            return RomInfo(
                "三星",
                "One UI",
                oneUi.ifEmpty { prop("ro.build.version.incremental") },
                verdict,
                "One UI 8",
            )
        }

        // 其它品牌 / 类原生（含 AOSP、LineageOS）：按 AOSP 16 的实时通知算
        val isAosp16 = Build.VERSION.SDK_INT >= 36
        val name = prop("ro.build.display.id").ifEmpty {
            if (isAosp16) "Android ${Build.VERSION.RELEASE}" else "Android ${Build.VERSION.RELEASE}"
        }
        return RomInfo(
            manufacturer.ifEmpty { "未知品牌" },
            name,
            prop("ro.build.version.incremental"),
            if (isAosp16) Verdict.SUPPORTED else Verdict.UNTESTED,
            "Android 16",
        )
    }

    /** 给 Dart 侧的扁平结构 */
    fun snapshot(): Map<String, Any> {
        val i = info()
        Log.i(TAG, "rom=${i.brand}/${i.romName}/${i.version} verdict=${i.verdict}")
        return mapOf(
            "brand" to i.brand,
            "rom" to i.romName,
            "version" to i.version,
            "required" to i.required,
            "verdict" to when (i.verdict) {
                Verdict.SUPPORTED -> "supported"
                Verdict.LOW_VERSION -> "low"
                Verdict.UNTESTED -> "untested"
            },
        )
    }
}
