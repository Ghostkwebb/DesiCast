import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:iptv_optimized_in/features/playlist/logic/playlist_cubit.dart';
import 'package:iptv_optimized_in/features/playlist/ui/home_screen.dart';

void main() {
  // 1. Initialize MediaKit (Critical for FFI/Hardware Accel)
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  runApp(const IPTVApp());
}

class IPTVApp extends StatelessWidget {
  const IPTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DesiCast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF141414),
        // Enhance default typography
        primaryColor: Colors.cyan,
      ),
      home: BlocProvider(
        create: (context) => PlaylistCubit()..loadPlaylist(),
        child: const HomeScreen(),
      ),
    );
  }
}
