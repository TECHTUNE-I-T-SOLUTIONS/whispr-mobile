// Spoken Word model for audio/video content
class SpokenWord {
  final String id;
  final String title;
  final String? description;
  final String type; // 'audio' or 'video'
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? duration; // in seconds
  final String? createdAt;
  final String? publishedAt;
  final SpokenWordAuthor author;
  final int? viewCount;
  final int? likesCount;

  SpokenWord({
    required this.id,
    required this.title,
    this.description,
    required this.type,
    this.mediaUrl,
    this.thumbnailUrl,
    this.duration,
    this.createdAt,
    this.publishedAt,
    required this.author,
    this.viewCount,
    this.likesCount,
  });

  factory SpokenWord.fromJson(Map<String, dynamic> json) {
    return SpokenWord(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      type: json['type'] ?? 'audio',
      mediaUrl: json['media_file']?['file_url'] ?? json['media_url'],
      thumbnailUrl: json['thumbnail_url'],
      duration: json['duration'],
      createdAt: json['created_at'],
      publishedAt: json['published_at'],
      author: SpokenWordAuthor.fromJson(json['author'] ?? {}),
      viewCount: json['view_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
    );
  }
}

class SpokenWordAuthor {
  final String id;
  final String name;
  final String? avatar;

  SpokenWordAuthor({
    required this.id,
    required this.name,
    this.avatar,
  });

  factory SpokenWordAuthor.fromJson(Map<String, dynamic> json) {
    return SpokenWordAuthor(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Unknown',
      avatar: json['avatar'],
    );
  }
}