package com.fugood.reactnativemultibleperipheral

import com.facebook.react.bridge.ReadableMap

class Utils {

  companion object {

    fun getString(map: ReadableMap?, key: String): String? {
      if (map == null) return null
      return when (map.hasKey(key)) {
        true -> map.getString(key)
        else -> null
      }
    }

    fun getInt(map: ReadableMap?, key: String): Int? {
      if (map == null) return null
      return when (map.hasKey(key)) {
        true -> map.getInt(key)
        else -> null
      }
    }

    fun <T: Boolean> get(map: ReadableMap?, key: String, defaultVal: Boolean): Boolean {
      if (map == null) return defaultVal
      return when (map.hasKey(key)) {
        true -> map.getBoolean(key)
        else -> defaultVal
      }
    }

    fun <T: String> get(map: ReadableMap?, key: String, defaultVal: String): String {
      return getString(map, key) ?: defaultVal
    }

    fun <T: Int> get(map: ReadableMap?, key: String, defaultVal: Int): Int {
      return getInt(map, key) ?: defaultVal
    }

  }

}
