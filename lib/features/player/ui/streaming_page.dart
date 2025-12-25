import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:iptv_optimized_in/features/player/logic/optimized_stream_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class StreamingPage extends StatefulWidget {
  final String streamUrl;
  final String channelName;

  const StreamingPage({super.key, required this.streamUrl, required this.channelName});

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage> {
  late final OptimizedStreamController _streamController;
  bool _showDebugOverlay = true;
  BoxFit _fit = BoxFit.contain;
  
  // Performance State (Defaults found in Nuclear Research)
  bool _motionSmoothness = true; // Default: skiploopfilter=all
  bool _forceVideoFlow = true;   // Default: video-sync=desync

  @override
  void initState() {
    super.initState();
    // Enable WakeLock to prevent screen from sleeping during playback
    WakelockPlus.enable();
    
    _streamController = OptimizedStreamController();
    // Start playing the provided URL
    _streamController.play(widget.streamUrl);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _streamController.dispose();
    super.dispose();
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'Video Settings',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Aspect Ratio / Fit',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildFitOption(Icons.fit_screen, 'Fit', BoxFit.contain),
                  _buildFitOption(Icons.crop_free, 'Fill', BoxFit.fill),
                  _buildFitOption(Icons.zoom_out_map, 'Zoom', BoxFit.cover),
                ],
              ),
              const SizedBox(height: 32),
              
              Text(
                'Performance',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              
              // 1. Motion Smoothness Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.greenAccent,
                title: Text('Motion Smoothness (Fix Stutter)', style: GoogleFonts.inter(color: Colors.white)),
                subtitle: Text('Reduces visual quality to force smooth playback.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                value: _motionSmoothness, 
                onChanged: (val) {
                  setState(() => _motionSmoothness = val);
                  _streamController.setMotionSmoothness(val);
                },
              ),
              
              // 2. Audio Priority Toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: Colors.blueAccent,
                title: Text('Prioritize Lip-Sync', style: GoogleFonts.inter(color: Colors.white)),
                subtitle: Text('Enable if audio is out of sync. May cause buffering.', style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
                value: !_forceVideoFlow, // UI shows "Lip Sync" (re-sample), Logic is "Force Video" (desync)
                onChanged: (val) {
                  setState(() => _forceVideoFlow = !val);
                  _streamController.setAudioSync(val);
                },
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildFitOption(IconData icon, String label, BoxFit fit) {
    final isSelected = _fit == fit;
    return GestureDetector(
      onTap: () {
        setState(() => _fit = fit);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isSelected ? Colors.black : Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Layer (Hardware Accelerated)
          // Using Video widget from media_kit_video
          Video(
            controller: _streamController.controller,
            controls: NoVideoControls, // We draw our own or use basic for now
            // Ensure aspect ratio is respected, or cover for full immersion
            fit: _fit, 
          ),

          // 2. Debug & Info Overlay (Toggleable)
          if (_showDebugOverlay)
            Positioned(
              top: 60,
              left: 20,
              child: _buildDebugOverlay(),
            ),
          
           // 3. UI Controls
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                // Settings Button
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: _showSettings,
                ),
                const SizedBox(width: 8),
                // Info Toggle
                IconButton(
                  icon: Icon(_showDebugOverlay ? Icons.info : Icons.info_outline, color: Colors.white),
                  onPressed: () => setState(() => _showDebugOverlay = !_showDebugOverlay),
                ),
                const SizedBox(width: 8),
                // Close Button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugOverlay() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           // ... (Existing Debug Logic) ...
          Text(
            widget.channelName,
            style: GoogleFonts.robotoMono(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          // Latency Indicator
          ValueListenableBuilder<Duration>(
            valueListenable: _streamController.currentLatency,
            builder: (context, latency, _) {
              final seconds = latency.inMilliseconds / 1000.0;
              Color color = Colors.green;
              if (seconds > 3.0) color = Colors.orange;
              if (seconds > 10.0) color = Colors.red;
              
              return Text(
                'Latency: ${seconds.toStringAsFixed(2)}s',
                style: GoogleFonts.robotoMono(color: color),
              );
            },
          ),
          // Speed Indicator
          ValueListenableBuilder<double>(
            valueListenable: _streamController.currentSpeed,
            builder: (context, speed, _) {
               return Text(
                'Speed: ${speed}x ${speed > 1.0 ? "(CATCH-UP)" : ""}',
                style: GoogleFonts.robotoMono(
                  color: speed > 1.0 ? Colors.cyanAccent : Colors.white70
                ),
              );
            },
          ),
          // Buffering Indicator
           ValueListenableBuilder<bool>(
            valueListenable: _streamController.isBuffering,
            builder: (context, buffering, _) {
              if (!buffering) return const SizedBox.shrink();
               return Text(
                'BUFFERING...',
                style: GoogleFonts.robotoMono(color: Colors.redAccent, fontWeight: FontWeight.bold),
              );
            },
          ),
        ],
      ),
    );
  }
}
