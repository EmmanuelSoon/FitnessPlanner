package com.example.fitnessplanner.utils

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator

object AudioVibratorHelper {
    fun playBeep(context: Context) {
        try {
            val toneGenerator = ToneGenerator(AudioManager.STREAM_NOTIFICATION, 100)
            toneGenerator.startTone(ToneGenerator.TONE_CDMA_ALERT, 200)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun vibrate(context: Context, duration: Long = 200) {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator?
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(duration)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun playBeepAndVibrate(context: Context) {
        playBeep(context)
        vibrate(context)
    }
}

