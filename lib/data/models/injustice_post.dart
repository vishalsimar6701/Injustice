class InjusticePost {
  final String id;
  final String content;
  final String category;
  final DateTime timestamp;
  final String evidenceUrl;
  final String state;
  final String district;
  final String city;
  final int reportCount;
  final String authorPubKey;
  final int verificationCount;
  final bool isVerifiedAuthor;

  InjusticePost({
    required this.id,
    required this.content,
    required this.category,
    required this.timestamp,
    required this.evidenceUrl,
    required this.state,
    required this.district,
    required this.city,
    this.reportCount = 0,
    this.authorPubKey = '',
    this.verificationCount = 0,
    this.isVerifiedAuthor = false,
  });

  InjusticePost copyWith({
    int? verificationCount,
    bool? isVerifiedAuthor,
  }) {
    return InjusticePost(
      id: id,
      content: content,
      category: category,
      timestamp: timestamp,
      evidenceUrl: evidenceUrl,
      state: state,
      district: district,
      city: city,
      reportCount: reportCount,
      authorPubKey: authorPubKey,
      verificationCount: verificationCount ?? this.verificationCount,
      isVerifiedAuthor: isVerifiedAuthor ?? this.isVerifiedAuthor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'category': category,
      'timestamp': timestamp.toIso8601String(),
      'evidenceUrl': evidenceUrl,
      'state': state,
      'district': district,
      'city': city,
      'reportCount': reportCount,
      'authorPubKey': authorPubKey,
    };
  }

  factory InjusticePost.fromJson(Map<String, dynamic> json) {
    return InjusticePost(
      id: json['id'] ?? '',
      content: json['content'] ?? '',
      category: json['category'] ?? 'General',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      evidenceUrl: json['evidenceUrl'] ?? '',
      state: json['state'] ?? 'Unknown',
      district: json['district'] ?? 'Unknown',
      city: json['city'] ?? 'Unknown',
      reportCount: json['reportCount'] ?? 0,
      authorPubKey: json['authorPubKey'] ?? '',
    );
  }
}
