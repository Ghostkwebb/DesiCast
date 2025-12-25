import 'package:http/http.dart' as http;

class Channel {
  final String name;
  final String? logoUrl;
  final String streamUrl;
  final String? group;

  const Channel({
    required this.name,
    this.logoUrl,
    required this.streamUrl,
    this.group,
  });
}

class M3UParser {
  /// Fetches and parses the M3U playlist from the given URL.
  Future<List<Channel>> parsePlaylist(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception('Failed to load playlist: ${response.statusCode}');
      }

      return _parseM3UContent(response.body);
    } catch (e) {
      // Re-throw or return empty list depending on desired error handling
      throw Exception('Error fetching playlist: $e');
    }
  }

  List<Channel> _parseM3UContent(String content) {
    final List<Channel> channels = [];
    final lines = content.split('\n');
    
    String? currentLogo;
    String? currentGroup;
    String? currentName;
    
    // Regex to extract attributes from #EXTINF line
    // Matches: tvg-logo="url", group-title="group", and the name at the end
    final logoRegExp = RegExp(r'tvg-logo="([^"]*)"');
    final groupRegExp = RegExp(r'group-title="([^"]*)"');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        // 1. Extract Metadata
        final logoMatch = logoRegExp.firstMatch(line);
        if (logoMatch != null) currentLogo = logoMatch.group(1);

        final groupMatch = groupRegExp.firstMatch(line);
        if (groupMatch != null) currentGroup = groupMatch.group(1);
        
        // Name is usually after the last comma
        final nameParts = line.split(',');
        if (nameParts.length > 1) {
          currentName = nameParts.last.trim();
        }
      } else if (!line.startsWith('#')) {
        // 2. This is the URL line (if it has metadata preceding it)
        if (currentName != null) {
          channels.add(Channel(
            name: currentName,
            logoUrl: currentLogo,
            group: currentGroup,
            streamUrl: line,
          ));
          
          // Reset for next entry
          currentName = null;
          currentLogo = null;
          currentGroup = null;
        }
      }
    }
    
    return channels;
  }
}
