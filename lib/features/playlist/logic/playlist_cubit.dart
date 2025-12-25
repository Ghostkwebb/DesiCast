import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:collection'; 
import 'package:iptv_optimized_in/features/playlist/data/m3u_parser.dart';

// --- STATES ---
abstract class PlaylistState extends Equatable {
  const PlaylistState();
  @override
  List<Object?> get props => [];
}

class PlaylistInitial extends PlaylistState {}

class PlaylistLoading extends PlaylistState {}

class PlaylistLoaded extends PlaylistState {
  final List<Channel> allChannels;
  final List<Channel> filteredChannels;
  final Set<String> categories;
  final String? selectedCategory;

  const PlaylistLoaded({
    required this.allChannels,
    required this.filteredChannels,
    required this.categories,
    this.selectedCategory,
  });

  PlaylistLoaded copyWith({
    List<Channel>? allChannels,
    List<Channel>? filteredChannels,
    Set<String>? categories,
    String? selectedCategory,
  }) {
    return PlaylistLoaded(
      allChannels: allChannels ?? this.allChannels,
      filteredChannels: filteredChannels ?? this.filteredChannels,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory, // Allow nulling out
    );
  }

  @override
  List<Object?> get props => [allChannels, filteredChannels, categories, selectedCategory];
}

class PlaylistError extends PlaylistState {
  final String message;
  const PlaylistError(this.message);
  @override
  List<Object?> get props => [message];
}

// --- CUBIT ---
class PlaylistCubit extends Cubit<PlaylistState> {
  final M3UParser _parser;
  // Official playlist URL for India
  static const String _playlistUrl = 'https://iptv-org.github.io/iptv/countries/in.m3u';

  PlaylistCubit({M3UParser? parser}) 
      : _parser = parser ?? M3UParser(),
        super(PlaylistInitial());

  Future<void> loadPlaylist() async {
    emit(PlaylistLoading());
    try {
      final channels = await _parser.parsePlaylist(_playlistUrl);
      
      if (channels.isEmpty) {
        emit(const PlaylistError('No channels found.'));
      } else {
        // Extract unique categories (groups)
        final categories = channels
            .map((c) => c.group)
            .where((g) => g != null && g.isNotEmpty)
            .cast<String>()
            .toSet();

        // Sort categories alphabetically
        final sortedCategories = SplayTreeSet<String>.from(categories);

        emit(PlaylistLoaded(
          allChannels: channels,
          filteredChannels: channels,
          categories: sortedCategories,
          selectedCategory: null, // 'All' selected by default
        ));
      }
    } catch (e) {
      emit(PlaylistError('Failed to load playlist: $e'));
    }
  }

  void selectCategory(String? category) {
    if (state is PlaylistLoaded) {
      final currentState = state as PlaylistLoaded;
      
      if (category == null) {
        // Show all
        emit(currentState.copyWith(
          filteredChannels: currentState.allChannels,
          selectedCategory: null,
        ));
      } else {
        // Filter by category
        final filtered = currentState.allChannels.where((c) => c.group == category).toList();
        emit(currentState.copyWith(
          filteredChannels: filtered,
          selectedCategory: category,
        ));
      }
    }
  }

  void search(String query) {
    if (state is PlaylistLoaded) {
      final currentState = state as PlaylistLoaded;
      
      if (query.isEmpty) {
        // Reset to currently selected category or all
        selectCategory(currentState.selectedCategory);
        return;
      }

      final lowerQuery = query.toLowerCase();
      // Search operates on ALL channels, typically ignoring category filter to find global results
      // Or we could strict it to current category. Let's do Global Search for better UX.
      
      final filtered = currentState.allChannels.where((channel) {
        return channel.name.toLowerCase().contains(lowerQuery) || 
               (channel.group?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();

      emit(currentState.copyWith(
        filteredChannels: filtered,
        // We might want to clear selected category if searching globally, 
        // to indicate we are seeing search results, not strictly category results.
        // But let's keep it simple for now.
      ));
    }
  }
}
