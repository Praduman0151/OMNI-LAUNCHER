#!/usr/bin/env bash
# ==============================================================================
# OmniLauncher: All-in-One Android Launcher — Multi-Module Project Generator
# Run: bash setup_omnilauncher.sh && cd OmniLauncher && ./gradlew assembleDebug
# ==============================================================================
set -e
mkdir -p OmniLauncher
cd OmniLauncher

echo "Creating multi-module directories..."
mkdir -p app/src/main/java/com/omnilauncher/app
mkdir -p core/engine/src/main/java/com/omnilauncher/core/engine
mkdir -p core/data/src/main/java/com/omnilauncher/core/data
mkdir -p shell/classic/src/main/java/com/omnilauncher/shell/classic
mkdir -p shell/metro/src/main/java/com/omnilauncher/shell/metro
mkdir -p shell/motion3d/src/main/java/com/omnilauncher/shell/motion3d
mkdir -p shell/gaming/src/main/java/com/omnilauncher/shell/gaming
mkdir -p .github/workflows

cat << 'EOF_FILE' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools"
    package="com.omnilauncher.app">

    <!-- Core Launcher & Package Discovery Permissions -->
    <uses-permission android:name="android.permission.QUERY_ALL_PACKAGES"
        tools:ignore="QueryAllPackagesPermission" />
    <uses-permission android:name="android.permission.EXPAND_STATUS_BAR" />
    <uses-permission android:name="android.permission.REQUEST_DELETE_PACKAGES" />

    <!-- Gaming Shell: Playtime, DND & Floating FPS Overlay -->
    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
        tools:ignore="ProtectedPermissions" />
    <uses-permission android:name="android.permission.ACCESS_NOTIFICATION_POLICY" />
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <!-- On-demand Metro Live Tile Providers -->
    <uses-permission android:name="android.permission.READ_CALENDAR" />
    <uses-permission android:name="android.permission.READ_CONTACTS" />

    <application
        android:name=".OmniLauncherApp"
        android:allowBackup="true"
        android:label="OmniLauncher"
        android:supportsRtl="true"
        android:theme="@style/Theme.OmniLauncher">

        <!-- Main Home Launcher Activity -->
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTask"
            android:clearTaskOnLaunch="true"
            android:stateNotNeeded="true"
            android:windowSoftInputMode="adjustPan"
            android:configChanges="keyboard|keyboardHidden|navigation|orientation|screenSize|screenLayout|SmallestScreenSize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.HOME" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.MONKEY" />
            </intent-filter>
        </activity>

        <!-- Notification Badging & Metro Live Tile Feed -->
        <service
            android:name="com.omnilauncher.core.engine.OmniNotificationListener"
            android:exported="true"
            android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
            <intent-filter>
                <action android:name="android.service.notification.NotificationListenerService" />
            </intent-filter>
        </service>

        <!-- Gaming Shell Floating Performance Bubble -->
        <service
            android:name="com.omnilauncher.shell.gaming.GameOverlayService"
            android:exported="false" />
    </application>
</manifest>
EOF_FILE

cat << 'EOF_FILE' > app/build.gradle.kts
// =====================================================================
// settings.gradle.kts (Multi-Module Architecture)
// =====================================================================
rootProject.name = "OmniLauncher"
include(
    ":app",
    ":core:engine",
    ":core:data",
    ":core:ui",
    ":shell:classic",
    ":shell:metro",
    ":shell:motion3d",
    ":shell:gaming",
    ":feature:settings",
    ":feature:search",
    ":feature:backup"
)

// =====================================================================
// app/build.gradle.kts
// =====================================================================
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.dagger.hilt.android")
    id("com.google.devtools.ksp")
}

android {
    namespace = "com.omnilauncher.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.omnilauncher.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0-PRO"
    }

    buildFeatures {
        compose = true
    }
    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }
}

dependencies {
    implementation(project(":core:engine"))
    implementation(project(":core:data"))
    implementation(project(":core:ui"))
    implementation(project(":shell:classic"))
    implementation(project(":shell:metro"))
    implementation(project(":shell:motion3d"))
    implementation(project(":shell:gaming"))

    // Jetpack Compose BOM
    val composeBom = platform("androidx.compose:compose-bom:2024.09.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.2")

    // Hilt DI, Room & DataStore
    implementation("com.google.dagger:hilt-android:2.52")
    ksp("com.google.dagger:hilt-compiler:2.52")
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // Coil Icon Loader & Google Filament 3D Engine
    implementation("io.coil-kt:coil-compose:2.7.0")
    implementation("com.google.android.filament:filament-android:1.52.0")
}
EOF_FILE

cat << 'EOF_FILE' > core/engine/src/main/java/com/omnilauncher/core/engine/ShellManager.kt
package com.omnilauncher.core.engine

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.view.InputDevice
import androidx.compose.runtime.Composable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Contract implemented by Classic, Metro, Motion3D, and Gaming shells.
 */
interface LauncherShell {
    val id: String
    val displayName: String
    @Composable fun HomeScreen()
    @Composable fun AppList()
    fun onEnter()
    fun onExit()
}

@Singleton
class ShellManager @Inject constructor(
    private val shells: Map<String, @JvmSuppressWildcards LauncherShell>,
    private val appScope: CoroutineScope
) {
    private val _activeShell = MutableStateFlow(shells.getValue("classic"))
    val activeShell: StateFlow<LauncherShell> = _activeShell.asStateFlow()

    fun switchShell(targetId: String) {
        val next = shells[targetId] ?: return
        if (_activeShell.value.id == targetId) return
        _activeShell.value.onExit()
        _activeShell.value = next
        next.onEnter()
    }

    /**
     * Registers hardware automation triggers:
     * 1. Gamepad connected -> Switch to Gaming Shell
     * 2. Night AC Dock charging -> Switch to Motion 3D Clock Scene
     */
    fun registerAutomationReceivers(context: Context) {
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(Intent.ACTION_POWER_CONNECTED)
        }
        context.registerReceiver(object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                when (intent.action) {
                    BluetoothDevice.ACTION_ACL_CONNECTED -> {
                        if (hasGameControllerConnected()) {
                            appScope.launch { switchShell("gaming") }
                        }
                    }
                    Intent.ACTION_POWER_CONNECTED -> {
                        val hour = java.time.LocalTime.now().hour
                        if (hour >= 22 || hour <= 6) {
                            appScope.launch { switchShell("motion3d") }
                        }
                    }
                }
            }
        }, filter)
    }

    private fun hasGameControllerConnected(): Boolean {
        return InputDevice.getDeviceIds().any { id ->
            val src = InputDevice.getDevice(id)?.sources ?: 0
            (src and InputDevice.SOURCE_GAMEPAD) == InputDevice.SOURCE_GAMEPAD ||
            (src and InputDevice.SOURCE_JOYSTICK) == InputDevice.SOURCE_JOYSTICK
        }
    }
}
EOF_FILE

cat << 'EOF_FILE' > core/engine/src/main/java/com/omnilauncher/core/engine/AppRepository.kt
package com.omnilauncher.core.engine

import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.LauncherApps
import android.content.pm.ShortcutInfo
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Process
import android.os.UserManager
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

data class AppEntry(
    val label: String,
    val packageName: String,
    val componentName: ComponentName,
    val icon: Drawable,
    val isGame: Boolean,
    val isWorkProfile: Boolean
)

@Singleton
class AppRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val launcherApps = context.getSystemService(Context.LAUNCHER_APPS_SERVICE) as LauncherApps
    private val userManager = context.getSystemService(Context.USER_SERVICE) as UserManager

    private val _apps = MutableStateFlow<List<AppEntry>>(emptyList())
    val apps: StateFlow<List<AppEntry>> = _apps

    suspend fun reloadApps() = withContext(Dispatchers.IO) {
        val loaded = mutableListOf<AppEntry>()
        for (profile in userManager.userProfiles) {
            val isWork = profile != Process.myUserHandle()
            val activityList = launcherApps.getActivityList(null, profile)
            for (info in activityList) {
                val appInfo = info.applicationInfo
                val isGame = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appInfo.category == ApplicationInfo.CATEGORY_GAME
                } else {
                    (appInfo.flags and ApplicationInfo.FLAG_IS_GAME) != 0
                }
                loaded += AppEntry(
                    label = info.label.toString(),
                    packageName = appInfo.packageName,
                    componentName = info.componentName,
                    icon = info.getBadgedIcon(0),
                    isGame = isGame,
                    isWorkProfile = isWork
                )
            }
        }
        _apps.value = loaded.sortedBy { it.label.lowercase() }
    }

    fun getAppShortcuts(packageName: String): List<ShortcutInfo> {
        if (!launcherApps.hasShortcutHostPermission()) return emptyList()
        val query = LauncherApps.ShortcutQuery().apply {
            setPackage(packageName)
            setQueryFlags(
                LauncherApps.ShortcutQuery.FLAG_MATCH_DYNAMIC or
                LauncherApps.ShortcutQuery.FLAG_MATCH_MANIFEST or
                LauncherApps.ShortcutQuery.FLAG_MATCH_PINNED
            )
        }
        return launcherApps.getShortcuts(query, Process.myUserHandle()) ?: emptyList()
    }

    fun buildDefaultLauncherRoleIntent(context: Context): Intent? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = context.getSystemService(RoleManager::class.java)
            if (roleManager.isRoleAvailable(RoleManager.ROLE_HOME) &&
                !roleManager.isRoleHeld(RoleManager.ROLE_HOME)) {
                return roleManager.createRequestRoleIntent(RoleManager.ROLE_HOME)
            }
        }
        return Intent(android.provider.Settings.ACTION_HOME_SETTINGS)
    }
}
EOF_FILE

cat << 'EOF_FILE' > core/data/src/main/java/com/omnilauncher/core/data/DatabaseEntities.kt
package com.omnilauncher.core.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

@Entity(tableName = "shell_profiles")
data class ShellProfileEntity(
    @PrimaryKey val id: String,       // "classic", "metro", "motion3d", "gaming"
    val type: String,
    val themeJson: String
)

@Entity(tableName = "home_items")
data class HomeItemEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val shellId: String,
    val itemType: String,             // "app" | "widget" | "folder" | "tile"
    val cellX: Int,
    val cellY: Int,
    val spanX: Int,
    val spanY: Int,
    val page: Int,
    val payloadJson: String
)

@Entity(tableName = "metro_tiles")
data class TileEntity(
    @PrimaryKey val id: String,
    val packageName: String,
    val title: String,
    val size: String,                 // "1x1" | "2x2" | "4x2" | "4x4"
    val position: Int,
    val accentHex: String,
    val liveTileConfigJson: String
)

@Entity(tableName = "game_entries")
data class GameEntryEntity(
    @PrimaryKey val packageName: String,
    val title: String,
    val playtimeMs: Long,
    val lastPlayedEpoch: Long,
    val category: String
)

@Dao
interface LauncherDao {
    @Query("SELECT * FROM home_items WHERE shellId = :shellId ORDER BY page, cellY, cellX")
    fun observeHomeItems(shellId: String): Flow<List<HomeItemEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertHomeItem(item: HomeItemEntity)

    @Query("SELECT * FROM metro_tiles ORDER BY position ASC")
    fun observeMetroTiles(): Flow<List<TileEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMetroTiles(tiles: List<TileEntity>)

    @Query("SELECT * FROM game_entries ORDER BY lastPlayedEpoch DESC")
    fun observeGames(): Flow<List<GameEntryEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertGame(game: GameEntryEntity)
}

@Database(
    entities = [
        ShellProfileEntity::class,
        HomeItemEntity::class,
        TileEntity::class,
        GameEntryEntity::class
    ],
    version = 1,
    exportSchema = true
)
abstract class OmniLauncherDatabase : RoomDatabase() {
    abstract fun launcherDao(): LauncherDao
}
EOF_FILE

cat << 'EOF_FILE' > shell/metro/src/main/java/com/omnilauncher/shell/metro/MetroShellScreen.kt
package com.omnilauncher.shell.metro

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay

data class MetroTileUiModel(
    val id: String,
    val title: String,
    val liveContent: String,
    val spanCols: Int, // 1 (Small), 2 (Medium), 4 (Wide)
    val color: Color
)

@Composable
fun MetroShellScreen(
    tiles: List<MetroTileUiModel>,
    onTileClick: (MetroTileUiModel) -> Unit,
    onTileResize: (MetroTileUiModel) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(4),
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(
            items = tiles,
            key = { it.id },
            span = { GridItemSpan(it.spanCols) }
        ) { tile ->
            LiveMetroTile(
                tile = tile,
                onClick = { onTileClick(tile) },
                onLongPress = { onTileResize(tile) }
            )
        }
    }
}

@Composable
fun LiveMetroTile(
    tile: MetroTileUiModel,
    onClick: () -> Unit,
    onLongPress: () -> Unit
) {
    var flipped by remember { mutableStateOf(false) }
    var pressed by remember { mutableStateOf(false) }

    // Periodic Live Tile 3D Flip every 4.5 seconds
    LaunchedEffect(tile.id) {
        if (tile.spanCols > 1) {
            while (true) {
                delay(4500L)
                flipped = !flipped
            }
        }
    }

    val rotationX by animateFloatAsState(
        targetValue = if (flipped) 180f else 0f,
        animationSpec = tween(durationMillis = 700),
        label = "LiveTileFlip"
    )
    val tiltScale by animateFloatAsState(
        targetValue = if (pressed) 0.95f else 1f,
        label = "PressTilt"
    )

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(if (tile.spanCols == 1) 76.dp else 156.dp)
            .graphicsLayer {
                this.rotationX = rotationX
                this.scaleX = tiltScale
                this.scaleY = tiltScale
                this.cameraDistance = 14f * density
            }
            .background(tile.color)
            .pointerInput(Unit) {
                detectTapGestures(
                    onPress = {
                        pressed = true
                        tryAwaitRelease()
                        pressed = false
                    },
                    onTap = { onClick() },
                    onLongPress = { onLongPress() }
                )
            }
            .padding(12.dp)
    ) {
        if (rotationX <= 90f) {
            Text(
                text = tile.title,
                color = Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.BottomStart)
            )
        } else {
            // Back Face (inverted 180 deg on X axis so text is upright)
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer { this.rotationX = 180f }
            ) {
                Text(
                    text = tile.liveContent,
                    color = Color.White,
                    fontSize = 13.sp,
                    modifier = Modifier.align(Alignment.TopStart)
                )
                Text(
                    text = tile.title,
                    color = Color.White.copy(alpha = 0.8f),
                    fontSize = 11.sp,
                    modifier = Modifier.align(Alignment.BottomStart)
                )
            }
        }
    }
}
EOF_FILE

cat << 'EOF_FILE' > shell/motion3d/src/main/java/com/omnilauncher/shell/motion3d/Motion3DShellScreen.kt
package com.omnilauncher.shell.motion3d

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import kotlin.math.absoluteValue

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun Motion3DCubePager(
    pageCount: Int = 4,
    pageContent: @Composable (page: Int, pitch: Float, roll: Float) -> Unit
) {
    val pagerState = rememberPagerState(pageCount = { pageCount })
    val context = LocalContext.current

    // Gyroscope Sensor Parallax State
    var pitch by remember { mutableFloatStateOf(0f) }
    var roll by remember { mutableFloatStateOf(0f) }

    DisposableEffect(context) {
        val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val gyro = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                roll = (event.values[0] * 25f).coerceIn(-18f, 18f)
                pitch = (event.values[1] * 25f).coerceIn(-18f, 18f)
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        gyro?.let { sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_GAME) }
        onDispose { sensorManager.unregisterListener(listener) }
    }

    HorizontalPager(
        state = pagerState,
        modifier = Modifier.fillMaxSize()
    ) { page ->
        val pageOffset = (pagerState.currentPage - page) + pagerState.currentPageOffsetFraction

        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    cameraDistance = 16f * density
                    // 3D TSF Cube rotation around page edges
                    rotationY = pageOffset * -90f
                    transformOrigin = TransformOrigin(
                        pivotFractionX = if (pageOffset < 0f) 0f else 1f,
                        pivotFractionY = 0.5f
                    )
                    alpha = 1f - (pageOffset.absoluteValue * 0.35f)
                }
        ) {
            pageContent(page, pitch, roll)
        }
    }
}
EOF_FILE

cat << 'EOF_FILE' > shell/gaming/src/main/java/com/omnilauncher/shell/gaming/GamingShellEngine.kt
package com.omnilauncher.shell.gaming

import android.app.GameManager
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.os.PerformanceHintManager
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton

data class SystemPerfSnapshot(
    val batteryTempCelsius: Float,
    val batteryPercent: Int,
    val dndEnabled: Boolean
)

@Singleton
class GamingShellEngine @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val usageStats = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager

    /**
     * Queries UsageStatsManager for cumulative game foreground playtime over the last 30 days.
     */
    fun queryPlaytimeMs(packageName: String): Long {
        val now = System.currentTimeMillis()
        val thirtyDaysAgo = now - (30L * 24 * 60 * 60 * 1000)
        val statsMap = usageStats.queryAndAggregateUsageStats(thirtyDaysAgo, now)
        return statsMap[packageName]?.totalTimeInForeground ?: 0L
    }

    /**
     * One-Tap Game Mode:
     * 1. Enables Priority Do Not Disturb (if policy access granted)
     * 2. Configures Android 12+ GameManager & PerformanceHintManager session
     */
    fun setGameModeActive(enabled: Boolean) {
        if (notificationManager.isNotificationPolicyAccessGranted) {
            notificationManager.setInterruptionFilter(
                if (enabled) NotificationManager.INTERRUPTION_FILTER_PRIORITY
                else NotificationManager.INTERRUPTION_FILTER_ALL
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && enabled) {
            val perfHint = context.getSystemService(PerformanceHintManager::class.java)
            perfHint?.createHintSession(intArrayOf(android.os.Process.myTid()), 8_333_333L) // 120Hz target
        }
    }

    fun readTelemetry(): SystemPerfSnapshot {
        val intent = context.registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
        val tempTenths = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 360) ?: 360
        val level = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val dnd = notificationManager.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL
        return SystemPerfSnapshot(
            batteryTempCelsius = tempTenths / 10f,
            batteryPercent = level,
            dndEnabled = dnd
        )
    }
}
EOF_FILE

cat << 'EOF_FILE' > .github/workflows/android-apk.yml
name: Build OmniLauncher APK

on:
  push:
    branches: [ "main", "master" ]
  workflow_dispatch:

jobs:
  assemble-apk:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout OmniLauncher Source
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: gradle

      - name: Grant Execute Permission for Gradlew
        run: chmod +x gradlew

      - name: Compile Debug APK (All 4 Shells)
        run: ./gradlew assembleDebug --stacktrace

      - name: Upload Compiled OmniLauncher APK
        uses: actions/upload-artifact@v4
        with:
          name: OmniLauncher-v1.0.0-debug-apk
          path: app/build/outputs/apk/debug/app-debug.apk
EOF_FILE

echo "✅ OmniLauncher Android Studio project generated in ./OmniLauncher"
echo "👉 Open ./OmniLauncher in Android Studio or push to GitHub Actions to build app-debug.apk!"
