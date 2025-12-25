import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:iptv_optimized_in/core/config/stream_config.dart';

/// One-stop controller for managing the IPTV stream with optimized buffering
/// and "Catch-Up" logic.
class OptimizedStreamController {
  final Player player;
  late final VideoController controller;

  Timer? _catchUpTimer;
  bool _isDisposed = false;

  // Stream state status
  final ValueNotifier<double> currentSpeed = ValueNotifier(1.0);
  final ValueNotifier<Duration> currentLatency = ValueNotifier(Duration.zero);
  final ValueNotifier<bool> isBuffering = ValueNotifier(false);

  OptimizedStreamController() : player = Player(
    configuration: PlayerConfiguration(
      // Output to GPU (OpenGL), but DECODING will be Software (see below)
      vo: 'gpu', 
      
      // Buffer Management (Map Config to libmpv options)
      bufferSize: StreamConfig.bufferSizeByteLimit,
      
      // Low-level libmpv options
      libass: true,
    ),
  ) {
    controller = VideoController(player);
    _initializeOptions();
    _startCatchUpLoop(); // Re-enabled for Latency Monitoring
    _setupListeners();
  }

  /// Apply low-level demuxer and network options
  void _initializeOptions() {
    // 1. User-Agent & Headers
    if (player.platform is NativePlayer) {
      final nativePlayer = player.platform as NativePlayer;
      
      // Robust decoding for corrupted frames
      nativePlayer.setProperty('hwdec', 'auto-safe');
      
      nativePlayer.setProperty('user-agent', StreamConfig.userAgent);
    
      // 'http-header-fields' takes a comma-separated list of "Key: Value"
      // Filter out User-Agent since we set it explicitly above
      final customHeaders = StreamConfig.networkHeaders.entries
          .where((e) => e.key.toLowerCase() != 'user-agent');
          
      if (customHeaders.isNotEmpty) {
        final headers = customHeaders
            .map((e) => '${e.key}: ${e.value}')
            .join(',');
        nativePlayer.setProperty('http-header-fields', headers);
      }

      // 2. Buffering / HLS Optimization
      // Robust decoding for corrupted frames
      nativePlayer.setProperty('hwdec', 'auto-safe');
      
      // Network Resilience (Fix for "Stream ends prematurely" and "EAC3 errors")
      nativePlayer.setProperty('reconnect', 'yes');
      nativePlayer.setProperty('reconnect-delay-max', '0'); // Instant retry
      nativePlayer.setProperty('stream-buffer-size', '4M'); 
      nativePlayer.setProperty('dns-fast-fallback', 'yes');
      // Infinite Patience: Don't give up on the connection
      nativePlayer.setProperty('network-timeout', '60'); 
      
      // DEEP STABILIZATION (Round 9 - Error Tolerance)
      // 1. Ignore Decoding Errors. Tell FFmpeg to output silence instead of crashing on bad frames.
      nativePlayer.setProperty('ad-lavc-o', 'err_detect=ignore_err,strict=-2');
      
      // 2. Audio Setup (Stereo + Multi-threaded)
      nativePlayer.setProperty('audio-channels', 'stereo');
      nativePlayer.setProperty('ad-lavc-threads', '0'); 
      
      // 3. Relax Network Security
      nativePlayer.setProperty('tls-verify', 'no');
      
      // 4. Hardware Decoding (Reverted to 'auto-copy' for performance)
      // Software decoding caused stalls on 1080p. 'auto-copy' is robust and fast.
      nativePlayer.setProperty('hwdec', 'auto-copy'); 
      
      // 5. Massive Demuxer Buffers
      nativePlayer.setProperty('demuxer-lavf-probesize', '10000000'); // 10MB
      nativePlayer.setProperty('demuxer-lavf-buffersize', '10485760'); // 10MB internal buffer

      // 6. Smart Buffering (Balance between Stop and Stutter)
      // 'cache-pause=yes': Pause if buffer is empty (prevents freezing/glitching)
      // 'wait=5': Wait 5 seconds to build a decent buffer before resuming.
      nativePlayer.setProperty('cache-pause', 'yes');
      nativePlayer.setProperty('cache-pause-initial', 'yes');
      nativePlayer.setProperty('cache-pause-wait', '5');
      
      // 7. Decoder Tolerance for corrupt/late frames
      nativePlayer.setProperty('framedrop', 'no'); 
      // 'desync': Don't wait for audio to sync video. Just play frames as they arrive.
      nativePlayer.setProperty('video-sync', 'desync'); 
      nativePlayer.setProperty('autosync', '30'); 
      
      // 8. Advanced Error Concealment (Nuclear Option)
      nativePlayer.setProperty('vd-lavc-skiploopfilter', 'all'); 
      // 'favor_inter' helps predict missing blocks from previous frames
      nativePlayer.setProperty('vd-lavc-o', 'ec=guess_mvs+deblock+favor_inter');
      // Ignore audio errors to prevent AC3 crashes
      nativePlayer.setProperty('ad-lavc-o', 'err_detect=ignore_err');
      
      // 9. Advanced Buffering
      nativePlayer.setProperty('demuxer-readahead-secs', '60');
      nativePlayer.setProperty('cache-back-buffer', '10000');
      
      // Ensure we have a safety buffer before playing
      nativePlayer.setProperty('demuxer-min-duration', StreamConfig.minBufferDurationSeconds.toString());
      
      // Ensure we have a safety buffer before playing
      nativePlayer.setProperty('demuxer-min-duration', StreamConfig.minBufferDurationSeconds.toString());
      // Allow the demuxer to look ahead up to 60s (or whatever config says)
      nativePlayer.setProperty('demuxer-max-duration', StreamConfig.maxBufferDurationSeconds.toString());
      
      // Enable aggressive caching
      nativePlayer.setProperty('cache', 'yes');
      nativePlayer.setProperty('demuxer-max-bytes', StreamConfig.bufferSizeByteLimit.toString());
      
      // Prefer higher quality if available
      nativePlayer.setProperty('hls-bitrate', 'max');
    }
  }

  void _setupListeners() {
    player.stream.buffering.listen((buffering) {
      isBuffering.value = buffering;
      debugPrint('[StreamController] Buffering: $buffering');
    });
    
    player.stream.error.listen((error) {
       debugPrint('[StreamController] ERROR: $error');
    });

    player.stream.log.listen((log) {
      debugPrint('[libmpv] ${log.prefix}: ${log.text}');
    });
    
    player.stream.completed.listen((completed) {
       debugPrint('[StreamController] Completed: $completed');
    });
    
    player.stream.width.listen((width) {
       debugPrint('[StreamController] Video Width: $width');
    });
    
    player.stream.height.listen((height) {
       debugPrint('[StreamController] Video Height: $height');
    });
  }

  /// Start playback of a new stream URL
  Future<void> play(String url) async {
    await player.open(Media(url));
  }

  /// The heartbeat of the "Catch-Up" mode.
  /// Checks latency every 1 second and adjusts playback speed.
  void _startCatchUpLoop() {
    _catchUpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _adjustPlaybackSpeed();
    });
  }

  void _adjustPlaybackSpeed() {
    // If not playing or buffering, don't mess with speed
    if (!player.state.playing || isBuffering.value) return;

    final duration = player.state.duration;
    final position = player.state.position;

    // Approximating Live Edge:
    // For HLS, 'duration' usually represents the sliding window's end.
    // So Latency ~= Duration - Position.
    // NOTE: This varies by HLS playlist type (Event vs Live).
    if (duration == Duration.zero) return; // Not ready yet

    final latency = duration - position;
    currentLatency.value = latency;

    double latencySeconds = latency.inMilliseconds / 1000.0;
    
    // ALGORITHM IMPLEMENTATION
    
    // 1. Lag Zone: Too far behind (> 10s)
    if (latencySeconds > StreamConfig.latencyLagZoneSeconds) {
       // Seek to Live Edge - 3s (Safe Zone)
       // We subtract 3s to give the buffer a moment to fill before hitting the edge
       final targetPosition = duration - const Duration(seconds: 3);
       player.seek(targetPosition);
       // Reset speed to normal after seek
       _setSpeed(StreamConfig.normalPlaybackSpeed);
       debugPrint('[StreamController] LAG DETECTED ($latencySeconds s). SEELING TO LIVE.');
    }
    // 2. Catch Wait Zone: 3s - 10s
    else if (latencySeconds > StreamConfig.latencySafeZoneSeconds) {
      // Gently speed up
      if (player.state.rate != StreamConfig.catchUpPlaybackSpeed) {
        _setSpeed(StreamConfig.catchUpPlaybackSpeed);
        debugPrint('[StreamController] CATCH-UP ACTIVE. Latency: $latencySeconds s');
      }
    }
    // 3. Safe Zone: < 3s
    else {
      // Normal speed
      if (player.state.rate != StreamConfig.normalPlaybackSpeed) {
        _setSpeed(StreamConfig.normalPlaybackSpeed);
        debugPrint('[StreamController] LIVE EDGE RESTORED. Latency: $latencySeconds s');
      }
    }
  }

  void _setSpeed(double speed) {
    player.setRate(speed);
    currentSpeed.value = speed;
  }

  void setMotionSmoothness(bool enabled) {
    // 'enabled' = Nuclear Mode (Fix Stutter)
    if (enabled) {
      // 1. Skip Filters (Speed)
      (player.platform as NativePlayer).setProperty('vd-lavc-skiploopfilter', 'all');
      
      // 2. Maximum Error Concealment (HW Safe)
      (player.platform as NativePlayer).setProperty('vd-lavc-o', 'ec=guess_mvs+deblock');
      debugPrint('[StreamController] Smoothness: NUCLEAR (SkipLoop: ALL)');
    } else {
      // Quality Mode
      // We do NOT change hwdec at runtime to avoid crash
      (player.platform as NativePlayer).setProperty('vd-lavc-skiploopfilter', 'none');
       (player.platform as NativePlayer).setProperty('vd-lavc-o', 'ec=guess_mvs+deblock');
      debugPrint('[StreamController] Smoothness: QUALITY (LoopFilter: NONE)');
    }
  }

  void setAudioSync(bool prioritizeAudio) {
    // 'display-resample' = Wait for Audio (Lip Sync)
    // 'desync' = Ignore Audio (Video Flow)
    final val = prioritizeAudio ? 'display-resample' : 'desync';
    (player.platform as NativePlayer).setProperty('video-sync', val);
    debugPrint('[StreamController] Video Sync set to: $val');
  }

  Future<void> dispose() async { // Existing dispose
    _isDisposed = true;
    _catchUpTimer?.cancel();
    await player.dispose();
  }
}
