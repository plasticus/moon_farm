# WorkManager's Room-generated WorkDatabase_Impl is loaded via reflection at
# runtime. Without a keep rule, R8 strips/renames it in release builds, which
# crashes on launch with "Failed to create an instance of
# androidx.work.impl.WorkDatabase". WorkManager is pulled in transitively by
# google_mobile_ads (Play Services background tasks), not used directly here.
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
-keep class * extends androidx.room.RoomDatabase
