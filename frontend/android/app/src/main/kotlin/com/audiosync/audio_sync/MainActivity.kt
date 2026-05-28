package com.audiosync.audio_sync

import android.content.Context
import android.media.AudioManager
import android.media.audiofx.Equalizer
import android.media.audiofx.PresetReverb
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val EFFECTS_CHANNEL = "com.midnight.audio_sync/audio_effects"
    private val ROUTING_CHANNEL = "com.midnight.audio_sync/audio_routing"

    private var equalizer: Equalizer? = null
    private var reverb: PresetReverb? = null
    private var currentSessionId: Int? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Equalizer and Reverb Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EFFECTS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initEffects" -> {
                    val sessionId = call.argument<Int>("sessionId")
                    if (sessionId != null && sessionId > 0) {
                        initEffects(sessionId)
                        result.success(true)
                    } else {
                        result.error("INVALID_SESSION", "Session ID is null or invalid", null)
                    }
                }
                "setBandLevel" -> {
                    val band = call.argument<Int>("band")
                    val level = call.argument<Int>("level")
                    if (band != null && level != null) {
                        setBandLevel(band.toShort(), level.toShort())
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Band or level is null", null)
                    }
                }
                "setReverbPreset" -> {
                    val preset = call.argument<String>("preset")
                    if (preset != null) {
                        setReverbPreset(preset)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Preset is null", null)
                    }
                }
                "releaseEffects" -> {
                    releaseEffects()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Speaker / Earpiece Routing Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ROUTING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAudioRoute" -> {
                    val route = call.argument<String>("route")
                    if (route != null) {
                        val success = setAudioRoute(route)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Route is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initEffects(sessionId: Int) {
        try {
            if (currentSessionId == sessionId && equalizer != null) return

            releaseEffects()
            currentSessionId = sessionId

            equalizer = Equalizer(0, sessionId).apply {
                enabled = true
            }

            reverb = PresetReverb(0, sessionId).apply {
                enabled = true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setBandLevel(band: Short, level: Short) {
        try {
            equalizer?.let { eq ->
                if (band in 0 until eq.numberOfBands) {
                    val milliBelLevel = (level * 100).toShort()
                    eq.setBandLevel(band, milliBelLevel)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setReverbPreset(preset: String) {
        try {
            reverb?.let { rev ->
                rev.preset = when (preset.lowercase()) {
                    "cathedral" -> PresetReverb.PRESET_PLATE
                    "ambient" -> PresetReverb.PRESET_MEDIUMHALL
                    "studio" -> PresetReverb.PRESET_SMALLROOM
                    "live" -> PresetReverb.PRESET_LARGEROOM
                    else -> PresetReverb.PRESET_NONE
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun releaseEffects() {
        try {
            equalizer?.release()
            equalizer = null
            reverb?.release()
            reverb = null
            currentSessionId = null
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun setAudioRoute(route: String): Boolean {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        return try {
            when (route.lowercase()) {
                "speaker" -> {
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = true
                    true
                }
                "earpiece" -> {
                    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                    audioManager.isSpeakerphoneOn = false
                    true
                }
                else -> {
                    audioManager.mode = AudioManager.MODE_NORMAL
                    audioManager.isSpeakerphoneOn = false
                    true
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    override fun onDestroy() {
        releaseEffects()
        super.onDestroy()
    }
}
