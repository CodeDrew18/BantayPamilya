package com.example.bantay_pamilya

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.Telephony
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "com.example.bantay_pamilya/app_blocker"
    private val monitoringPermissions = arrayOf(
        Manifest.permission.READ_CALL_LOG,
        Manifest.permission.READ_SMS,
        Manifest.permission.READ_CONTACTS,
    )

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
                    "requestMonitoringPermissions" -> {
                        requestMonitoringPermissions()
                        result.success(null)
                    }
                    "getCallLogs" -> {
                        val limit = call.argument<Int>("limit") ?: 50
                        result.success(getCallLogs(limit))
                    }
                    "getSmsLogs" -> {
                        val limit = call.argument<Int>("limit") ?: 50
                        result.success(getSmsLogs(limit))
                    }
                    "getContacts" -> {
                        val limit = call.argument<Int>("limit") ?: 100
                        result.success(getContacts(limit))
                    }
					else -> result.notImplemented()
				}
			}
	}

    private fun requestMonitoringPermissions() {
        val denied = monitoringPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (denied.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, denied.toTypedArray(), 3210)
        }
    }

    private fun getCallLogs(limit: Int): List<Map<String, Any?>> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CALL_LOG)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return emptyList()
        }

        val rows = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CallLog.Calls.NUMBER,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.TYPE,
            CallLog.Calls.DURATION,
            CallLog.Calls.DATE,
        )
        contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            projection,
            null,
            null,
            "${CallLog.Calls.DATE} DESC",
        )?.use { cursor ->
            val numberIx = cursor.getColumnIndex(CallLog.Calls.NUMBER)
            val nameIx = cursor.getColumnIndex(CallLog.Calls.CACHED_NAME)
            val typeIx = cursor.getColumnIndex(CallLog.Calls.TYPE)
            val durationIx = cursor.getColumnIndex(CallLog.Calls.DURATION)
            val dateIx = cursor.getColumnIndex(CallLog.Calls.DATE)

            var count = 0
            while (cursor.moveToNext() && count < limit) {
                rows.add(
                    mapOf(
                        "number" to cursor.getString(numberIx),
                        "name" to cursor.getString(nameIx),
                        "type" to cursor.getInt(typeIx),
                        "duration" to cursor.getLong(durationIx),
                        "date" to cursor.getLong(dateIx),
                    )
                )
                count += 1
            }
        }
        return rows
    }

    private fun getSmsLogs(limit: Int): List<Map<String, Any?>> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return emptyList()
        }

        val rows = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.TYPE,
            Telephony.Sms.DATE,
        )
        contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val addressIx = cursor.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIx = cursor.getColumnIndex(Telephony.Sms.BODY)
            val typeIx = cursor.getColumnIndex(Telephony.Sms.TYPE)
            val dateIx = cursor.getColumnIndex(Telephony.Sms.DATE)

            var count = 0
            while (cursor.moveToNext() && count < limit) {
                rows.add(
                    mapOf(
                        "address" to cursor.getString(addressIx),
                        "body" to cursor.getString(bodyIx),
                        "type" to cursor.getInt(typeIx),
                        "date" to cursor.getLong(dateIx),
                    )
                )
                count += 1
            }
        }
        return rows
    }

    private fun getContacts(limit: Int): List<Map<String, Any?>> {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return emptyList()
        }

        val rows = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            projection,
            null,
            null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC",
        )?.use { cursor ->
            val nameIx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numberIx = cursor.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)

            var count = 0
            while (cursor.moveToNext() && count < limit) {
                rows.add(
                    mapOf(
                        "name" to cursor.getString(nameIx),
                        "number" to cursor.getString(numberIx),
                    )
                )
                count += 1
            }
        }
        return rows
    }
}
