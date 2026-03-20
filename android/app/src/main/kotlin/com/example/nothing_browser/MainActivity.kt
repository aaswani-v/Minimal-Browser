package com.example.nothing_browser

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

	companion object {
		private const val CHANNEL_NAME = "com.example.nothing_browser/media"
		const val ACTION_MEDIA_BROADCAST = "com.example.nothing_browser.MEDIA_ACTION"
		private var mediaChannel: MethodChannel? = null
		private val mainHandler = Handler(Looper.getMainLooper())

		fun sendMediaActionToFlutter(action: String) {
			mainHandler.post {
				mediaChannel?.invokeMethod("onMediaAction", mapOf("action" to action))
			}
		}
	}

	private val mediaActionReceiver = object : BroadcastReceiver() {
		override fun onReceive(context: Context?, intent: Intent?) {
			val action = intent?.getStringExtra("action") ?: return
			sendMediaActionToFlutter(action)
		}
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		val filter = IntentFilter(ACTION_MEDIA_BROADCAST)
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			registerReceiver(mediaActionReceiver, filter, RECEIVER_NOT_EXPORTED)
		} else {
			registerReceiver(mediaActionReceiver, filter)
		}
	}

	override fun onDestroy() {
		unregisterReceiver(mediaActionReceiver)
		super.onDestroy()
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		mediaChannel = MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			CHANNEL_NAME
		)

		mediaChannel?.setMethodCallHandler { call, result ->
			when (call.method) {
				"startService" -> {
					val title = call.argument<String>("title") ?: "Minimal Browser"
					val artist = call.argument<String>("artist") ?: "Playing"
					val artUrl = call.argument<String>("artUrl")

					val intent = Intent(this, MediaPlaybackService::class.java).apply {
						action = MediaPlaybackService.ACTION_START
						putExtra(MediaPlaybackService.EXTRA_TITLE, title)
						putExtra(MediaPlaybackService.EXTRA_ARTIST, artist)
						putExtra(MediaPlaybackService.EXTRA_ART_URL, artUrl)
					}

					if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
						startForegroundService(intent)
					} else {
						startService(intent)
					}

					result.success(true)
				}

				"stopService" -> {
					val intent = Intent(this, MediaPlaybackService::class.java).apply {
						action = MediaPlaybackService.ACTION_STOP
					}
					startService(intent)
					stopService(Intent(this, MediaPlaybackService::class.java))
					result.success(true)
				}

				"updateMetadata" -> {
					val title = call.argument<String>("title") ?: "Minimal Browser"
					val artist = call.argument<String>("artist") ?: "Playing"
					val artUrl = call.argument<String>("artUrl")

					if (MediaPlaybackService.isRunning()) {
						MediaPlaybackService.updateMetadata(title, artist, artUrl)
						result.success(true)
					} else {
						result.success(false)
					}
				}

				"setPlaying" -> {
					val isPlaying = call.argument<Boolean>("isPlaying") ?: true
					if (MediaPlaybackService.isRunning()) {
						MediaPlaybackService.setPlaying(isPlaying)
					}
					result.success(true)
				}

				else -> result.notImplemented()
			}
		}
	}
}
