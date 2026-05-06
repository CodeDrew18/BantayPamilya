package com.example.bantay_pamilya

import android.content.Context

object AppBlockerPrefs {
    private const val prefsName = "app_blocker_prefs"
    private const val keyBlocked = "blocked_packages"

    fun saveBlockedPackages(context: Context, packages: List<String>) {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        prefs.edit().putStringSet(keyBlocked, packages.toSet()).apply()
    }

    fun getBlockedPackages(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        return prefs.getStringSet(keyBlocked, emptySet()) ?: emptySet()
    }
}
