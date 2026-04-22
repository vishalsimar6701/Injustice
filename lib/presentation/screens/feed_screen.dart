import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/injustice_post.dart';
import '../../data/repositories/data_service.dart';
import '../../core/location_data.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

enum SortOption { newest, category, location }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<InjusticePost> _posts = [];
  late Future<Stream<InjusticePost>> _streamFuture;
  StreamSubscription? _subscription;
  SortOption _currentSort = SortOption.newest;
  final ImagePicker _picker = ImagePicker();
  
  // Filtering state
  String? _filterState;
  String? _filterDistrict;
  bool _isConnected = true;
  Timer? _connectionTimer;

  @override
  void initState() {
    super.initState();
    _loadFilters();
    _initNostr();
    _startConnectionCheck();
  }

  void _startConnectionCheck() {
    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final connected = DataService.isAnyRelayConnected;
      if (connected != _isConnected) {
        setState(() => _isConnected = connected);
      }
    });
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _filterState = prefs.getString('filter_state');
      _filterDistrict = prefs.getString('filter_district');
    });
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    if (_filterState != null) {
      await prefs.setString('filter_state', _filterState!);
    } else {
      await prefs.remove('filter_state');
    }
    
    if (_filterDistrict != null) {
      await prefs.setString('filter_district', _filterDistrict!);
    } else {
      await prefs.remove('filter_district');
    }
  }

  void _initNostr() {
    _streamFuture = DataService.getPostsStream().then((stream) {
      _subscription?.cancel();
      _subscription = stream.listen((post) {
        if (mounted) {
          setState(() {
            if (!_posts.any((p) => p.id == post.id)) {
              _posts.add(post);
              _sortPosts();
            }
          });
        }
      });
      return stream;
    });
  }

  Future<void> _refreshFeed() async {
    setState(() {
      _posts.clear();
      _initNostr();
    });
    // Give it a moment to fetch some posts
    await Future.delayed(const Duration(seconds: 1));
  }

  void _sortPosts() {
    setState(() {
      switch (_currentSort) {
        case SortOption.newest:
          _posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          break;
        case SortOption.category:
          _posts.sort((a, b) => a.category.compareTo(b.category));
          break;
        case SortOption.location:
          _posts.sort((a, b) => a.state.compareTo(b.state));
          break;
      }
    });
  }

  List<InjusticePost> get _filteredPosts {
    return _posts.where((post) {
      bool stateMatch = _filterState == null || post.state == _filterState;
      bool districtMatch = _filterDistrict == null || post.district == _filterDistrict;
      return stateMatch && districtMatch;
    }).toList();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACCOUNTABILITY FEED'),
        actions: [
          IconButton(
            icon: Icon(Icons.location_searching, color: (_filterState != null) ? AppTheme.goldAccent : Colors.white),
            onPressed: () => _showFilterDialog(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'relay') {
                _showRelayDialog(context);
              } else {
                setState(() {
                  _currentSort = SortOption.values.firstWhere((e) => e.toString() == value);
                  _sortPosts();
                });
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: SortOption.newest.toString(), child: const Text('Sort by Newest')),
              PopupMenuItem(value: SortOption.category.toString(), child: const Text('Sort by Category')),
              PopupMenuItem(value: SortOption.location.toString(), child: const Text('Sort by State')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'relay', child: Text('Manage Communities (Relays)')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_isConnected)
            Container(
              width: double.infinity,
              color: AppTheme.errorRed,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                'OFFLINE: Connecting to decentralized network...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          if (_filterState != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.midnightBlue.withAlpha(20),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: AppTheme.midnightBlue),
                  const SizedBox(width: 8),
                  Text('Filtering: $_filterState${_filterDistrict != null ? ", $_filterDistrict" : ""}', 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.midnightBlue)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() { 
                        _filterState = null; 
                        _filterDistrict = null; 
                      });
                      _saveFilters();
                    },
                    child: const Text('Clear', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                  )
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshFeed,
              color: AppTheme.midnightBlue,
              child: FutureBuilder(
                future: _streamFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && _posts.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final displayPosts = _filteredPosts;
                  if (displayPosts.isEmpty) {
                    return ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        const Center(child: Text('No reports match your filters.')),
                        const Center(child: Text('Pull down to refresh.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                      ],
                    );
                  }

                  return ListView.builder(
                    itemCount: displayPosts.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (context, index) {
                      return _buildPostCard(context, displayPosts[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPostDialog(context),
        backgroundColor: AppTheme.midnightBlue,
        child: const Icon(Icons.add_comment_rounded, color: AppTheme.goldAccent),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, InjusticePost post) {
    bool isImageUrl = post.evidenceUrl.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)'));
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(post.category.toUpperCase(), style: const TextStyle(color: AppTheme.midnightBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    Text(DateFormat('dd MMM, HH:mm').format(post.timestamp), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${post.city}, ${post.district}, ${post.state}', 
                      style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                    if (post.isVerifiedAuthor) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded, color: AppTheme.goldAccent, size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        // Optimistic UI update
                        setState(() {
                          final index = _posts.indexWhere((p) => p.id == post.id);
                          if (index != -1) {
                            _posts[index] = _posts[index].copyWith(
                              verificationCount: _posts[index].verificationCount + 1,
                            );
                          }
                        });
                        await DataService.verifyPost(post.id, post.authorPubKey);
                      },
                      icon: const Icon(Icons.shield_outlined, size: 16, color: AppTheme.midnightBlue),
                      label: Text('VERIFY (${post.verificationCount})', 
                        style: const TextStyle(color: AppTheme.midnightBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.midnightBlue.withAlpha(15),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 20, color: AppTheme.midnightBlue),
                      onPressed: () {
                        final text = 'REPORT: ${post.category}\nLocation: ${post.city}, ${post.state}\n\n${post.content}\n\nEvidence: ${post.evidenceUrl}\n\nShared via Injustice Accountability Platform';
                        SharePlus.instance.share(
                          ShareParams(text: text),
                        );
                      },
                      tooltip: 'Share Report',
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Block Author?'),
                            content: const Text('You will no longer see any reports from this author.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('BLOCK', style: TextStyle(color: AppTheme.errorRed))),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await DataService.blockAuthor(post.authorPubKey);
                          setState(() {
                            _posts.removeWhere((p) => p.authorPubKey == post.authorPubKey);
                          });
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Author blocked.'))
                          );
                        }
                      },
                      child: const Text('BLOCK', style: TextStyle(color: AppTheme.errorRed, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        await DataService.hidePost(post.id);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post reported and hidden from your feed.'))
                        );
                        setState(() { _posts.removeWhere((p) => p.id == post.id); });
                      },
                      icon: const Icon(Icons.flag_outlined, size: 16, color: AppTheme.errorRed),
                      label: const Text('REPORT', style: TextStyle(color: AppTheme.errorRed, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (post.evidenceUrl.isNotEmpty)
            Column(
              children: [
                if (isImageUrl)
                  Image.network(
                    post.evidenceUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                InkWell(
                  onTap: () => launchUrl(Uri.parse(post.evidenceUrl)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.midnightBlue.withAlpha(10),
                      border: const Border(top: BorderSide(color: Colors.black12)),
                    ),
                    child: Row(
                      children: [
                        Icon(isImageUrl ? Icons.remove_red_eye_rounded : Icons.attachment_rounded, size: 18, color: AppTheme.midnightBlue),
                        const SizedBox(width: 8),
                        Text(isImageUrl ? 'VIEW FULL IMAGE' : 'VIEW ATTACHED EVIDENCE', style: const TextStyle(color: AppTheme.midnightBlue, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    String? selectedState = _filterState;
    String? selectedDistrict = _filterDistrict;

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('FILTER BY LOCATION', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 16),
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Select State'),
                value: selectedState,
                items: LocationData.statesAndDistricts.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  setModalState(() {
                    selectedState = val;
                    selectedDistrict = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Select District'),
                value: selectedDistrict,
                items: (selectedState != null) 
                  ? LocationData.statesAndDistricts[selectedState]!.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList()
                  : [],
                onChanged: (val) {
                  setModalState(() => selectedDistrict = val);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _filterState = selectedState;
                    _filterDistrict = selectedDistrict;
                  });
                  _saveFilters();
                  Navigator.pop(context);
                },
                child: const Text('APPLY FILTERS'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await DataService.unblockAllAuthors();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _refreshFeed();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All authors unblocked.'))
                  );
                },
                child: const Text('RESET BLOCKED AUTHORS', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddPostDialog(BuildContext context) {
    final TextEditingController contentController = TextEditingController();
    final TextEditingController evidenceController = TextEditingController();
    final TextEditingController cityController = TextEditingController();
    String? selectedState;
    String? selectedDistrict;
    String category = 'General';
    XFile? pickedFile;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('REPORT INJUSTICE', style: Theme.of(context).textTheme.displayLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 3,
                  onChanged: (val) => setModalState(() {}),
                  decoration: const InputDecoration(hintText: 'What happened?', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                
                // Evidence Section
                const Text('EVIDENCE (Mandatory)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.midnightBlue)),
                const Text('Provide a link OR attach a photo/file below.', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: evidenceController,
                        onChanged: (val) {
                          if (pickedFile != null && val != pickedFile!.name) {
                            setModalState(() => pickedFile = null);
                          }
                          setModalState(() {}); // Ensure button state updates
                        },
                        decoration: const InputDecoration(
                          hintText: 'Paste link here...', 
                          prefixIcon: Icon(Icons.link), 
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: isUploading ? null : () async {
                        final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
                        if (file != null) {
                          setModalState(() {
                            pickedFile = file;
                            evidenceController.text = file.name;
                          });
                        }
                      },
                      icon: const Icon(Icons.photo_library_rounded),
                      style: IconButton.styleFrom(backgroundColor: AppTheme.midnightBlue, foregroundColor: AppTheme.goldAccent),
                    ),
                    IconButton.filled(
                      onPressed: isUploading ? null : () async {
                        final XFile? file = await _picker.pickImage(source: ImageSource.camera);
                        if (file != null) {
                          setModalState(() {
                            pickedFile = file;
                            evidenceController.text = file.name;
                          });
                        }
                      },
                      icon: const Icon(Icons.camera_alt_rounded),
                      style: IconButton.styleFrom(backgroundColor: AppTheme.midnightBlue, foregroundColor: AppTheme.goldAccent),
                    ),
                  ],
                ),
                if (pickedFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.midnightBlue.withAlpha(50)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                            child: Image.file(File(pickedFile!.path), height: 100, width: 100, fit: BoxFit.cover),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(pickedFile!.name, style: const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis)),
                                  Text('${(File(pickedFile!.path).lengthSync() / 1024).toStringAsFixed(1)} KB', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setModalState(() {
                              pickedFile = null;
                              evidenceController.clear();
                            }),
                            icon: const Icon(Icons.close, color: AppTheme.errorRed),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Choose State'),
                  value: selectedState,
                  items: LocationData.statesAndDistricts.keys.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    setModalState(() {
                      selectedState = val;
                      selectedDistrict = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('Choose District'),
                  value: selectedDistrict,
                  items: (selectedState != null) 
                    ? LocationData.statesAndDistricts[selectedState]!.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList()
                    : [],
                  onChanged: (val) {
                    setModalState(() => selectedDistrict = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  onChanged: (val) => setModalState(() {}),
                  decoration: const InputDecoration(hintText: 'City / Village Name', prefixIcon: Icon(Icons.map_outlined), border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: category,
                  isExpanded: true,
                  items: ['General', 'Corruption', 'Police', 'Consumer', 'Labor'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setModalState(() => category = val!),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (contentController.text.isNotEmpty && evidenceController.text.isNotEmpty && selectedState != null && selectedDistrict != null && cityController.text.isNotEmpty && !isUploading) 
                    ? () async {
                        setModalState(() => isUploading = true);
                        try {
                          String finalEvidenceUrl = evidenceController.text;
                          
                          if (pickedFile != null) {
                            // Upload the file
                            finalEvidenceUrl = await DataService.uploadFile(File(pickedFile!.path));
                          }
                          
                          await DataService.publishPost(
                            content: contentController.text,
                            category: category,
                            evidenceUrl: finalEvidenceUrl,
                            state: selectedState!,
                            district: selectedDistrict!,
                            city: cityController.text,
                          );
                          if (!context.mounted) return;
                          Navigator.pop(context);
                          _refreshFeed();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          if (mounted) setModalState(() => isUploading = false);
                        }
                      } 
                    : null,
                  child: isUploading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldAccent))
                    : const Text('BROADCAST REPORT'),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRelayDialog(BuildContext context) {
    final TextEditingController relayController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('MANAGE COMMUNITIES', style: Theme.of(context).textTheme.displayLarge),
              const Text('Connect to local servers for better moderation.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: relayController,
                      decoration: const InputDecoration(hintText: 'wss://relay.example.com', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (relayController.text.isNotEmpty) {
                        await DataService.addRelay(relayController.text);
                        relayController.clear();
                        setModalState(() {});
                      }
                    },
                    child: const Text('ADD'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('ACTIVE COMMUNITIES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: DataService.activeRelays.length,
                  itemBuilder: (context, index) {
                    final relay = DataService.activeRelays[index];
                    return ListTile(
                      title: Text(relay, style: const TextStyle(fontSize: 14)),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorRed),
                        onPressed: () async {
                          await DataService.removeRelay(relay);
                          setModalState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

