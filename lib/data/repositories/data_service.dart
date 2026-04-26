import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/injustice_post.dart';

class DataService {
  static final Nostr _nostr = Nostr.instance;
  static const int _postKind = 1;
  static const int _reactionKind = 7;
  static const int _deletionKind = 5;
  static const int _powDifficulty = 8; 

  // List of public keys for trusted NGOs, Journalists, etc.
  static const List<String> _trustedPubKeys = [
    'npub1...', // Placeholder for actual trusted keys
  ];

  static const List<String> _defaultRelays = [
    'wss://nos.lol',
    'wss://relay.damus.io',
    'wss://relay.snort.social',
    'wss://relay.nostr.band',
  ];

  static List<String> _activeRelays = [];

  // Global filter for legally required takedowns (can be fetched from an external URL)
  static const List<String> _globalBlacklist = []; 

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _activeRelays = prefs.getStringList('user_relays') ?? List.from(_defaultRelays);

    await _nostr.services.relays.init(
      relaysUrl: _activeRelays, 
      onRelayConnectionError: (url, error, webSocket) {
        debugPrint('Relay Connection Error: $url - $error');
      }, 
      onRelayListening: (url, receivedData, webSocket) {
        debugPrint('Relay Listening: $url');
      }
    );
  }

  static Future<void> addRelay(String url) async {
    if (_activeRelays.contains(url)) return;
    _activeRelays.add(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_relays', _activeRelays);
    // Initialize the new relay
    await _nostr.services.relays.init(relaysUrl: [url]);
  }

  static Future<void> removeRelay(String url) async {
    _activeRelays.remove(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('user_relays', _activeRelays);
    // In a real app, we might want to disconnect the relay here, 
    // but Nostr.instance usually manages the pool based on the init call.
  }

  static List<String> get activeRelays => List.unmodifiable(_activeRelays);

  static bool get isAnyRelayConnected {
    try {
      // In dart_nostr 9.2.5, we check the relaysWebSocketsRegistry
      return _nostr.services.relays.relaysWebSocketsRegistry.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking relay connection: $e');
      return false;
    }
  }

  static Future<String> uploadFile(File file) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('https://nostr.build/api/v2/upload/files'));
      request.files.add(await http.MultipartFile.fromPath('file[]', file.path));

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        if (data['data'] != null && data['data'] is List && data['data'].isNotEmpty) {
          return data['data'][0]['url'];
        }
        throw Exception('Unexpected response format from media service');
      } else {
        throw Exception('Failed to upload file: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      throw Exception('Media upload failed. Please check your connection.');
    }
  }

  static Future<String> _getOrGeneratePrivateKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? key = prefs.getString('private_key');
    if (key == null) {
      key = _nostr.services.keys.generatePrivateKey();
      await prefs.setString('private_key', key);
    }
    return key;
  }

  static Future<String> getUserPubKey() async {
    final privKey = await _getOrGeneratePrivateKey();
    return _nostr.services.keys.derivePublicKey(privateKey: privKey);
  }

  static Future<void> deletePost(String postId) async {
    final privateKey = await _getOrGeneratePrivateKey();
    
    final event = NostrEvent.fromPartialData(
      kind: _deletionKind,
      content: 'Requesting deletion of this report.',
      tags: [
        ['e', postId],
      ],
      keyPairs: NostrKeyPairs(private: privateKey),
    );
    
    await _nostr.services.relays.sendEventToRelays(event);
    // Also hide it locally immediately
    await hidePost(postId);
  }

  static Future<void> hidePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList('hidden_posts') ?? [];
    if (!hidden.contains(postId)) {
      hidden.add(postId);
      await prefs.setStringList('hidden_posts', hidden);
    }
  }
static Future<List<String>> getHiddenPosts() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('hidden_posts') ?? [];
}

static Future<void> blockAuthor(String pubKey) async {
  final prefs = await SharedPreferences.getInstance();
  final blocked = prefs.getStringList('blocked_authors') ?? [];
  if (!blocked.contains(pubKey)) {
    blocked.add(pubKey);
    await prefs.setStringList('blocked_authors', blocked);
  }
}

static Future<void> unblockAllAuthors() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('blocked_authors');
}

static Future<List<String>> getBlockedAuthors() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('blocked_authors') ?? [];
}

static Future<Stream<InjusticePost>> getPostsStream() async {
  final hiddenIds = await getHiddenPosts();
  final blockedPubKeys = await getBlockedAuthors();

  final request = NostrRequest(
    filters: [
      NostrFilter(
        kinds: const [_postKind, _reactionKind],
        t: const ['injustice'],
        limit: 300, // Increased limit to fetch reactions too
      ),
    ],
  );

  final nostrStream = _nostr.services.relays.startEventsSubscription(request: request);

  // We'll use a local map to track counts since we can't easily aggregate on relays
  final Map<String, int> reactionCounts = {};

  return nostrStream.stream.where((event) {
    if (blockedPubKeys.contains(event.pubkey)) return false;
    if (_globalBlacklist.contains(event.id)) return false;

    if (event.kind == _postKind) {
      return _getDifficulty(event.id ?? '') >= _powDifficulty && !hiddenIds.contains(event.id);
    }
    return event.kind == _reactionKind;
  }).map((event) {
      if (event.kind == _reactionKind) {
        final targetId = _getTagValue(event.tags, 'e');
        if (targetId.isNotEmpty) {
          reactionCounts[targetId] = (reactionCounts[targetId] ?? 0) + 1;
        }
        // Return a dummy post that will be filtered out by the UI logic later
        return InjusticePost(
          id: 'reaction_${event.id}',
          content: '', category: '', timestamp: DateTime.now(), evidenceUrl: '', state: '', district: '', city: '',
          authorPubKey: event.pubkey,
        );
      }

      return InjusticePost(
        id: event.id ?? '',
        content: event.content ?? '',
        category: _getTagValue(event.tags, 'c', 'General'),
        timestamp: event.createdAt ?? DateTime.now(),
        evidenceUrl: _getTagValue(event.tags, 'evidence'),
        state: _getTagValue(event.tags, 's', 'Unknown'),
        district: _getTagValue(event.tags, 'd', 'Unknown'),
        city: _getTagValue(event.tags, 'l', 'Unknown'),
        authorPubKey: event.pubkey,
        isVerifiedAuthor: _trustedPubKeys.contains(event.pubkey),
        verificationCount: reactionCounts[event.id] ?? 0,
      );
    }).where((post) => !post.id.startsWith('reaction_'));
  }

  static Future<void> verifyPost(String postId, String authorPubKey) async {
    final privateKey = await _getOrGeneratePrivateKey();
    
    final event = NostrEvent.fromPartialData(
      kind: _reactionKind,
      content: '+', // Standard Nostr reaction for "like/upvote"
      tags: [
        ['e', postId],
        ['p', authorPubKey],
        ['t', 'injustice'], // Keep it in the same namespace
      ],
      keyPairs: NostrKeyPairs(private: privateKey),
    );
    
    _nostr.services.relays.sendEventToRelays(event);
  }

  static Future<void> publishPost({
    required String content,
    required String category,
    required String evidenceUrl,
    required String state,
    required String district,
    required String city,
  }) async {
    final privateKey = await _getOrGeneratePrivateKey();
    
    // Offload PoW mining to a background isolate
    final params = _MiningParams(
      content: content,
      category: category,
      evidenceUrl: evidenceUrl,
      state: state,
      district: district,
      city: city,
      privateKey: privateKey,
      difficulty: _powDifficulty,
    );

    final eventMap = await compute(_mineEvent, params.toJson());
    
    // Reconstruct NostrEvent from the map returned by isolate
    final event = NostrEvent(
      id: eventMap['id'],
      kind: eventMap['kind'],
      content: eventMap['content'],
      sig: eventMap['sig'],
      pubkey: eventMap['pubkey'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(eventMap['created_at'] * 1000),
      tags: List<List<String>>.from(
        (eventMap['tags'] as List).map((t) => List<String>.from(t as List))
      ),
    );
    
    _nostr.services.relays.sendEventToRelays(event);
  }

  static Map<String, dynamic> _mineEvent(Map<String, dynamic> paramsJson) {
    final params = _MiningParams.fromJson(paramsJson);
    int nonce = 0;
    while (true) {
      final tags = [
        ['t', 'injustice'],
        ['c', params.category],
        ['evidence', params.evidenceUrl],
        ['s', params.state],
        ['d', params.district],
        ['l', params.city],
        ['nonce', nonce.toString(), params.difficulty.toString()],
      ];

      final event = NostrEvent.fromPartialData(
        kind: 1,
        content: params.content,
        tags: tags,
        keyPairs: NostrKeyPairs(private: params.privateKey),
      );
      
      if (_getDifficulty(event.id ?? '') >= params.difficulty) {
        return event.toMap();
      }
      nonce++;
    }
  }

  static int _getDifficulty(String id) {
    if (id.isEmpty) return 0;
    int difficulty = 0;
    for (int i = 0; i < id.length; i++) {
      int charCode = int.parse(id[i], radix: 16);
      if (charCode == 0) {
        difficulty += 4;
      } else {
        difficulty += [4, 3, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0][charCode];
        break;
      }
    }
    return difficulty;
  }

  static String _getTagValue(List<List<String>>? tags, String tagKey, [String defaultValue = '']) {
    if (tags == null) return defaultValue;
    try {
      final tag = tags.firstWhere((t) => t.length > 1 && t[0] == tagKey);
      return tag[1];
    } catch (_) {
      return defaultValue;
    }
  }
}

class _MiningParams {
  final String content;
  final String category;
  final String evidenceUrl;
  final String state;
  final String district;
  final String city;
  final String privateKey;
  final int difficulty;

  _MiningParams({
    required this.content,
    required this.category,
    required this.evidenceUrl,
    required this.state,
    required this.district,
    required this.city,
    required this.privateKey,
    required this.difficulty,
  });

  Map<String, dynamic> toJson() => {
    'content': content,
    'category': category,
    'evidenceUrl': evidenceUrl,
    'state': state,
    'district': district,
    'city': city,
    'privateKey': privateKey,
    'difficulty': difficulty,
  };

  factory _MiningParams.fromJson(Map<String, dynamic> json) => _MiningParams(
    content: json['content'],
    category: json['category'],
    evidenceUrl: json['evidenceUrl'],
    state: json['state'],
    district: json['district'],
    city: json['city'],
    privateKey: json['privateKey'],
    difficulty: json['difficulty'],
  );
}
