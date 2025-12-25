/// Configuration for the Optimized Stream Controller.
/// 
/// These values are exposed to allow the user to fine-tune the playback experience
/// based on their specific network conditions (e.g., high latency, jitter) and device memory.
class StreamConfig {
  
  // ===========================================================================
  // User-Agent & Network Headers
  // ===========================================================================
  
  /// The User-Agent string sent to the streaming server.
  /// 
  /// Many IPTV providers block generic player User-Agents (like "LibVLC" or "ExoPlayer").
  /// This string mimics a standard Desktop Chrome browser to prevent 403 Forbidden errors.
  static const String userAgent = 
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3';

  /// Additional HTTP headers to send with the stream request.
  /// 
  /// Add Referer or Origin headers here if your provider requires them.
  static const Map<String, String> networkHeaders = {
    'User-Agent': userAgent,
    // 'Referer': 'https://some-referer.com/', // Uncomment and set if needed
  };

  // ===========================================================================
  // Buffering Configuration (libmpv properties)
  // ===========================================================================

  /// The amount of data (in bytes) the player is allowed to buffer in RAM.
  /// 
  /// Impact:
  /// - Higher values: Smoother playback on unstable networks, but higher Memory usage.
  /// - Lower values: Lower latency, less memory usage.
  /// 
  /// Default: 128MB (128 * 1024 * 1024) - Increased for HD Stream Stability.
  static const int bufferSizeByteLimit = 128 * 1024 * 1024; 

  /// Minimum data (in seconds) required to START playback.
  /// 
  /// Impact:
  /// - Higher values: Slower startup time, but less likely to stall immediately.
  /// - Lower values: Direct "Live" feel, but higher risk of initial stutter.
  /// 
  /// Default: 15 seconds (Increased for 1080p Stability).
  /// This forces the player to "load ahead" 15s before starting, creating a safety net for HD streams.
  static const int minBufferDurationSeconds = 15;
  
  /// Maximum data (in seconds) to prefetch.
  /// 
  /// Allows the player to download ahead during good network conditions.
  static const int maxBufferDurationSeconds = 120; // Increased to 2 mins for safety

  // ===========================================================================
  // Catch-Up / Latency Management
  // ===========================================================================

  /// The default playback speed.
  static const double normalPlaybackSpeed = 1.0;

  /// The playback speed used when the player detects it has fallen behind the live edge.
  /// 
  /// Reduced to 1.02x (from 1.05x) to be less aggressive.
  /// This prevents draining the buffer too quickly on unstable connections.
  static const double catchUpPlaybackSpeed = 1.02;

  /// The Safe Zone threshold in seconds.
  /// 
  /// ESTIMATED LATENCY SAFE ZONE.
  /// We increased this to 25.0s to allow the 15s buffer to exist without the catch-up mechanics
  /// trying to speed up and drain it. You stay "behind" but stable.
  static const double latencySafeZoneSeconds = 25.0;

  /// The Catch-Up Zone threshold in seconds.
  /// 
  /// If Latency is > 40s, gently speed up.
  static const double latencyCatchUpZoneSeconds = 40.0;
  
  /// The Lag Zone threshold in seconds.
  /// 
  /// If Latency > 60s, force seek to live.
  static const double latencyLagZoneSeconds = 60.0;
}
