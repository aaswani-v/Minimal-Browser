package com.example.nothing_browser

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.os.Build
import android.os.IBinder
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle
import coil.ImageLoader
import coil.request.ImageRequest
import coil.request.SuccessResult
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

class MediaPlaybackService : Service() {

    companion object {
        const val ACTION_START = "com.example.nothing_browser.media.START"
        const val ACTION_STOP = "com.example.nothing_browser.media.STOP"
        const val ACTION_UPDATE_METADATA = "com.example.nothing_browser.media.UPDATE_METADATA"
        const val ACTION_PREV = "com.example.nothing_browser.media.PREV"
        const val ACTION_PLAY_PAUSE = "com.example.nothing_browser.media.PLAY_PAUSE"
        const val ACTION_NEXT = "com.example.nothing_browser.media.NEXT"

        const val EXTRA_TITLE = "extra_title"
        const val EXTRA_ARTIST = "extra_artist"
        const val EXTRA_ART_URL = "extra_art_url"

        private const val CHANNEL_ID = "media_playback"
        private const val CHANNEL_NAME = "Media Playback"
        private const val NOTIFICATION_ID = 9001

        @Volatile
        private var instance: MediaPlaybackService? = null

        fun updateMetadata(title: String, artist: String, artUrl: String?) {
            instance?.updateMetadataInternal(title, artist, artUrl)
        }

        fun setPlaying(playing: Boolean) {
            instance?.setPlayingState(playing)
        }

        fun isRunning(): Boolean = instance != null
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var mediaSession: MediaSessionCompat

    private var currentTitle: String = "Minimal Browser"
    private var currentArtist: String = "Playing"
    private var currentArtUrl: String? = null
    private var isPlaying: Boolean = true
    private var currentArtwork: Bitmap? = null

    override fun onCreate() {
        super.onCreate()
        instance = this

        mediaSession = MediaSessionCompat(this, "MinimalBrowserMediaSession").apply {
            isActive = true
        }

        createNotificationChannelIfNeeded()
        updatePlaybackState()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_UPDATE_METADATA -> {
                val title = intent.getStringExtra(EXTRA_TITLE) ?: currentTitle
                val artist = intent.getStringExtra(EXTRA_ARTIST) ?: currentArtist
                val artUrl = intent.getStringExtra(EXTRA_ART_URL)
                updateMetadataInternal(title, artist, artUrl)
                return START_STICKY
            }

            ACTION_PREV -> {
                broadcastMediaAction("prev")
                return START_STICKY
            }

            ACTION_PLAY_PAUSE -> {
                isPlaying = !isPlaying
                updatePlaybackState()
                refreshNotification()
                broadcastMediaAction("play_pause")
                return START_STICKY
            }

            ACTION_NEXT -> {
                broadcastMediaAction("next")
                return START_STICKY
            }

            else -> {
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: currentTitle
                val artist = intent?.getStringExtra(EXTRA_ARTIST) ?: currentArtist
                val artUrl = intent?.getStringExtra(EXTRA_ART_URL)
                currentTitle = title
                currentArtist = artist
                currentArtUrl = artUrl

                val initialNotification = buildNotification()
                startForegroundCompat(initialNotification)
                loadArtworkAsync(artUrl)
                return START_STICKY
            }
        }
    }

    override fun onDestroy() {
        serviceScope.cancel()
        mediaSession.release()
        instance = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun updateMetadataInternal(title: String, artist: String, artUrl: String?) {
        currentTitle = title
        currentArtist = artist
        currentArtUrl = artUrl

        updateMediaSessionMetadata(currentArtwork)
        refreshNotification()
        loadArtworkAsync(artUrl)
    }

    private fun setPlayingState(playing: Boolean) {
        isPlaying = playing
        updatePlaybackState()
        refreshNotification()
    }

    private fun updatePlaybackState() {
        val state = if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED
        val actions = PlaybackStateCompat.ACTION_PLAY or
            PlaybackStateCompat.ACTION_PAUSE or
            PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
            PlaybackStateCompat.ACTION_SKIP_TO_NEXT

        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(actions)
                .setState(state, PlaybackStateCompat.PLAYBACK_POSITION_UNKNOWN, 1f)
                .build()
        )
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val launchPendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val prevIntent = Intent(this, MediaPlaybackService::class.java).setAction(ACTION_PREV)
        val playPauseIntent = Intent(this, MediaPlaybackService::class.java).setAction(ACTION_PLAY_PAUSE)
        val nextIntent = Intent(this, MediaPlaybackService::class.java).setAction(ACTION_NEXT)

        val prevPendingIntent = PendingIntent.getService(
            this,
            101,
            prevIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val playPausePendingIntent = PendingIntent.getService(
            this,
            102,
            playPauseIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val nextPendingIntent = PendingIntent.getService(
            this,
            103,
            nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val smallIcon = applicationInfo.icon
        val largeIcon = currentArtwork ?: BitmapFactory.decodeResource(resources, applicationInfo.icon)

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(smallIcon)
            .setLargeIcon(largeIcon)
            .setContentTitle(currentTitle)
            .setContentText(currentArtist)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(launchPendingIntent)
            .addAction(android.R.drawable.ic_media_previous, "Previous", prevPendingIntent)
            .addAction(
                if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play,
                if (isPlaying) "Pause" else "Play",
                playPausePendingIntent
            )
            .addAction(android.R.drawable.ic_media_next, "Next", nextPendingIntent)
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1, 2)
            )
            .build()
    }

    private fun refreshNotification() {
        updatePlaybackState()
        updateMediaSessionMetadata(currentArtwork)
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification())
    }

    private fun updateMediaSessionMetadata(artwork: Bitmap?) {
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, currentArtist)

        if (artwork != null) {
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, artwork)
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, artwork)
        }

        mediaSession.setMetadata(metadataBuilder.build())
    }

    private fun loadArtworkAsync(artUrl: String?) {
        if (artUrl.isNullOrBlank()) {
            currentArtwork = BitmapFactory.decodeResource(resources, applicationInfo.icon)
            refreshNotification()
            return
        }

        serviceScope.launch {
            try {
                val loader = ImageLoader(this@MediaPlaybackService)
                val request = ImageRequest.Builder(this@MediaPlaybackService)
                    .data(artUrl)
                    .allowHardware(false)
                    .build()
                val result = loader.execute(request)
                val drawable = (result as? SuccessResult)?.drawable
                val bitmap = when (drawable) {
                    is BitmapDrawable -> drawable.bitmap
                    else -> BitmapFactory.decodeResource(resources, applicationInfo.icon)
                }
                currentArtwork = bitmap
            } catch (_: Exception) {
                currentArtwork = BitmapFactory.decodeResource(resources, applicationInfo.icon)
            }

            launch(Dispatchers.Main) {
                refreshNotification()
            }
        }
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "Media playback controls"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        manager.createNotificationChannel(channel)
    }

    private fun broadcastMediaAction(action: String) {
        val intent = Intent(MainActivity.ACTION_MEDIA_BROADCAST).apply {
            setPackage(packageName)
            putExtra("action", action)
        }
        sendBroadcast(intent)
    }
}
