import 'dart:math';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iptv_optimized_in/features/player/ui/streaming_page.dart';
import 'package:iptv_optimized_in/features/playlist/data/m3u_parser.dart';
import 'package:iptv_optimized_in/features/playlist/logic/playlist_cubit.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    context.read<PlaylistCubit>().loadPlaylist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Apple TV True Black
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), // Heavy native blur
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
        ),
        title: Text('Start TV', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 20)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.search, color: Colors.white),
            onPressed: () {
             final cubit = context.read<PlaylistCubit>();
             Navigator.push(context, CupertinoPageRoute(builder: (_) => BlocProvider.value(value: cubit, child: const SearchScreen()), fullscreenDialog: true));
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: BlocBuilder<PlaylistCubit, PlaylistState>(
        builder: (context, state) {
          if (state is PlaylistLoaded) {
            // Responsive Variables
            final width = MediaQuery.of(context).size.width;
            final isDesktop = width > 800;
            final horizontalPadding = isDesktop ? 40.0 : 20.0;

            // Smart Grouping
            final news = state.allChannels.where((c) => c.group?.toLowerCase().contains('news') ?? false).toList();
            final sports = state.allChannels.where((c) => c.group?.toLowerCase().contains('sports') ?? false).toList();
            final music = state.allChannels.where((c) => c.group?.toLowerCase().contains('music') ?? false).toList();
            final movies = state.allChannels.where((c) => c.group?.toLowerCase().contains('movies') ?? false).toList();
            
            // Random Hero
            final heroChannel = state.allChannels.isNotEmpty 
                ? state.allChannels[Random().nextInt(state.allChannels.length)] 
                : null;

            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 50),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. HERO SECTION
                  if (heroChannel != null) _HeroSection(channel: heroChannel, isDesktop: isDesktop),
                  
                  SizedBox(height: isDesktop ? 40 : 20),

                  // 2. CATEGORY SWIMLANES
                  if (news.isNotEmpty) _CategorySection(title: 'Top News', channels: news, padding: horizontalPadding),
                  if (sports.isNotEmpty) _CategorySection(title: 'Sports', channels: sports, padding: horizontalPadding),
                  if (music.isNotEmpty) _CategorySection(title: 'Music', channels: music, padding: horizontalPadding),
                  if (movies.isNotEmpty) _CategorySection(title: 'Movies', channels: movies, padding: horizontalPadding),

                  // 3. ALL CHANNELS
                  Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 20),
                    child: Text('All Channels', style: GoogleFonts.inter(color: Colors.white, fontSize: isDesktop ? 24 : 20, fontWeight: FontWeight.w600)),
                  ),
                  
                  GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isDesktop ? 320 : 200, // Small cards on mobile for 2-col layout
                      childAspectRatio: 16 / 14, 
                      crossAxisSpacing: isDesktop ? 30 : 16,
                      mainAxisSpacing: isDesktop ? 30 : 16,
                    ),
                    itemCount: state.allChannels.length > 20 ? 20 : state.allChannels.length,
                    itemBuilder: (context, index) => _ContentCard(channel: state.allChannels[index]),
                  ),
                ],
              ),
            );
          } else if (state is PlaylistLoading) {
            return const Center(child: CupertinoActivityIndicator(radius: 20, color: Colors.white));
          } else if (state is PlaylistError) {
             return Center(child: Text(state.message, style: const TextStyle(color: Colors.white)));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final Channel channel;
  final bool isDesktop;
  
  const _HeroSection({required this.channel, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: isDesktop ? 600 : MediaQuery.of(context).size.height * 0.6, // Responsive Height
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          channel.logoUrl != null 
              ? CachedNetworkImage(
                  imageUrl: channel.logoUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_,__,___) => Container(color: Colors.grey[900]),
                )
              : Container(color: Colors.grey[900]),
          
          // Blur Overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          // Gradient Fade
          Container(
             decoration: const BoxDecoration(
               gradient: LinearGradient(
                 colors: [Colors.transparent, Colors.black],
                 begin: Alignment.topCenter,
                 end: Alignment.bottomCenter,
                 stops: [0.5, 1.0],
               ),
             ),
          ),
          
          // Content
          Positioned(
            left: isDesktop ? 60 : 20,
            right: isDesktop ? null : 20, // Constrain width on mobile
            bottom: isDesktop ? 80 : 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean Logo
                if (channel.logoUrl != null)
                   Container(
                     height: isDesktop ? 120 : 80, 
                     width: isDesktop ? 120 : 80,
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: Colors.white.withOpacity(0.1),
                       borderRadius: BorderRadius.circular(20),
                       boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 25)],
                     ),
                     child: CachedNetworkImage(imageUrl: channel.logoUrl!, fit: BoxFit.contain)
                   ),
                const SizedBox(height: 24),
                Text(
                  channel.name, 
                  style: GoogleFonts.inter(fontSize: isDesktop ? 56 : 32, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(channel.group ?? 'Trending Now', style: GoogleFonts.inter(fontSize: isDesktop ? 20 : 16, color: Colors.white70, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),
                CupertinoButton(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 32, vertical: isDesktop ? 18 : 14),
                  onPressed: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => StreamingPage(channelName: channel.name, streamUrl: channel.streamUrl))),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.play_arrow_solid, color: Colors.black),
                      const SizedBox(width: 8),
                      Text('Play', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w700, fontSize: isDesktop ? 18 : 16)),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String title;
  final List<Channel> channels;
  final double padding;

  const _CategorySection({required this.title, required this.channels, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: 15),
          child: Text(title, style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 280,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: 20),
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: channels.length > 10 ? 10 : channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 300,
                child: _ContentCard(channel: channels[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContentCard extends StatefulWidget {
  final Channel channel;
  const _ContentCard({required this.channel});

  @override
  State<_ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<_ContentCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => StreamingPage(channelName: widget.channel.name, streamUrl: widget.channel.streamUrl))),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Artwork Card
            AnimatedScale(
              scale: isHovered ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic, // Apple-like physics
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05), // Glassy placeholder
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isHovered 
                        ? [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 15))] 
                        : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: widget.channel.logoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: widget.channel.logoUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_,__,___) => const Icon(CupertinoIcons.tv, color: Colors.white24, size: 40),
                            )
                          : const Icon(CupertinoIcons.tv, color: Colors.white24, size: 40),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // 2. Metadata Below
            Text(
              widget.channel.name,
              style: GoogleFonts.inter(
                color: isHovered ? Colors.white : Colors.white70, 
                fontSize: 15, 
                fontWeight: FontWeight.w500
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.channel.group != null)
              Text(
                widget.channel.group!,
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Text('Search', style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon:Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
                  cursorColor: Colors.white,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    icon: Icon(CupertinoIcons.search, color: Colors.white54),
                    border: InputBorder.none,
                    hintText: 'Find channels (e.g. "News", "Sports")...',
                    hintStyle: GoogleFonts.inter(color: Colors.white24),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Results
            Expanded(
              child: BlocBuilder<PlaylistCubit, PlaylistState>(
                builder: (context, state) {
                  if (state is PlaylistLoaded) {
                     final results = _query.isEmpty 
                         ? <Channel>[] 
                         : state.allChannels.where((c) => c.name.toLowerCase().contains(_query.toLowerCase())).toList();
                     
                     if (_query.isNotEmpty && results.isEmpty) {
                       return Center(
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Icon(CupertinoIcons.search, size: 60, color: Colors.white10),
                             const SizedBox(height: 16),
                             Text('No channels found', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                           ],
                         ),
                       );
                     }
                     
                     if (results.isEmpty) {
                        return Center(
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             const Icon(CupertinoIcons.tv, size: 60, color: Colors.white10),
                             const SizedBox(height: 16),
                             Text('Search your favorite channels', style: GoogleFonts.inter(color: Colors.white38, fontSize: 16)),
                           ],
                         ),
                       );
                     }

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300,
                        childAspectRatio: 16 / 14, // Taller for safety
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: results.length,
                      itemBuilder: (context, index) => _ContentCard(channel: results[index]),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
