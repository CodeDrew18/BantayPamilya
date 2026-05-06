package com.example.bantay_pamilya

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "com.example.bantay_pamilya/app_blocker"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"setBlockedPackages" -> {
						val packages = call.argument<List<String>>("packages")
							?: emptyList()
						AppBlockerPrefs.saveBlockedPackages(this, packages)
						result.success(null)
					}
					"requestUsageAccess" -> {
						val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
						intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(null)
					}
					"requestAccessibilitySettings" -> {
						val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
						intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
						startActivity(intent)
						result.success(null)
					}
					else -> result.notImplemented()
				}
			}
	}
}
