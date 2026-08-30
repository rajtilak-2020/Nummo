package com.krajtilak.nummo

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.WindowManager
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private var refreshRateConfigured = false

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        // Defer high refresh rate configuration to avoid blocking cold launch Choreographer frames
        window.decorView.post {
            enableMaxRefreshRate()
        }
    }

    private fun enableMaxRefreshRate() {
        if (refreshRateConfigured) return
        refreshRateConfigured = true

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }

                val modes = display?.supportedModes ?: emptyArray()
                var maxMode: Display.Mode? = null
                var maxRate = 60f

                for (mode in modes) {
                    if (mode.refreshRate > maxRate) {
                        maxRate = mode.refreshRate
                        maxMode = mode
                    }
                }

                // If device only supports 60Hz or mode is null, do NOT modify window attributes.
                // This completely prevents MediaTek/Xiaomi ion memory allocator & surface negotiation frame drops.
                if (maxRate <= 60.5f || maxMode == null) {
                    return
                }

                val lp = window.attributes
                lp.preferredDisplayModeId = maxMode.modeId
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    lp.preferredRefreshRate = maxRate
                    window.setPreferMinimalPostProcessing(true)
                }
                window.attributes = lp
            } catch (e: Exception) {
                // Safely fallback if vendor platform prevents mode override
            }
        }
    }
}
