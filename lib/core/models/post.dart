// Unified Post model for feed (admin posts and user chronicles)
class Post {
  final String id;
  final String title;
  final String? content;
  final String? excerpt;
  final String type; // 'blog', 'poem', or 'chronicle'
  final String source; // 'admin' or 'user'
  final bool? featured;
  final int? readingTime;
  final List<String>? tags;
  final String? coverImage;
  final int? viewCount;
  final int? likesCount;
  final int? commentsCount;
  final int? sharesCount;
  final String? createdAt;
  final String? publishedAt;
  final PostAuthor author;
  final String? userReaction; // User's reaction to this post ('like', null)

  Post({
    required this.id,
    required this.title,
    this.content,
    this.excerpt,
    required this.type,
    required this.source,
    this.featured,
    this.readingTime,
    this.tags,
    this.coverImage,
    this.viewCount,
    this.likesCount,
    this.commentsCount,
    this.sharesCount,
    this.createdAt,
    this.publishedAt,
    required this.author,
    this.userReaction,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Untitled',
      content: json['content'],
      excerpt: json['excerpt'],
      type: json['type'] ?? 'blog',
      source: json['source'] ?? 'admin',
      featured: json['featured'],
      readingTime: json['readingTime'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : null,
      coverImage: json['coverImage'] ?? json['coverImageUrl'],
      viewCount: json['viewCount'] ?? json['viewsCount'],
      likesCount: json['likesCount'],
      commentsCount: json['commentsCount'],
      sharesCount: json['sharesCount'],
      createdAt: json['createdAt'],
      publishedAt: json['publishedAt'],
      author: PostAuthor.fromJson(json['authors'] ?? json['author'] ?? {}),
      userReaction: json['userReaction'],
    );
  }

  Post copyWith({
    String? id,
    String? title,
    String? content,
    String? excerpt,
    String? type,
    String? source,
    bool? featured,
    int? readingTime,
    List<String>? tags,
    String? coverImage,
    int? viewCount,
    int? likesCount,
    int? commentsCount,
    int? sharesCount,
    String? createdAt,
    String? publishedAt,
    PostAuthor? author,
    String? userReaction,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      excerpt: excerpt ?? this.excerpt,
      type: type ?? this.type,
      source: source ?? this.source,
      featured: featured ?? this.featured,
      readingTime: readingTime ?? this.readingTime,
      tags: tags ?? this.tags,
      coverImage: coverImage ?? this.coverImage,
      viewCount: viewCount ?? this.viewCount,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      sharesCount: sharesCount ?? this.sharesCount,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      author: author ?? this.author,
      userReaction: userReaction ?? this.userReaction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'excerpt': excerpt,
      'type': type,
      'source': source,
      'featured': featured,
      'readingTime': readingTime,
      'tags': tags,
      'coverImage': coverImage,
      'viewCount': viewCount,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'sharesCount': sharesCount,
      'createdAt': createdAt,
      'publishedAt': publishedAt,
      'author': author.toJson(),
    };
  }

  String get displayDate {
    final date = publishedAt != null ? DateTime.tryParse(publishedAt!) : null;
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

  String get readingTimeText {
    if (readingTime == null) return '';
    return '$readingTime min read';
  }
}

class PostAuthor {
  final String id;
  final String name;
  final String? username;
  final String? avatar;
  final String type; // 'admin' or 'creator'

  PostAuthor({
    required this.id,
    required this.name,
    this.username,
    this.avatar,
    required this.type,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Anonymous',
      username: json['username'],
      avatar: json['avatar_url'] ?? json['avatar'],
      type: json['type'] ?? 'admin',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'avatar': avatar,
      'type': type,
    };
  }
}

// Wall Post model for Whispr Wall (Q&A format)
class WallPost {
  final String id;
  final String content; // User's question/message
  final List<WallResponse>? responses; // All responses to this post
  final String? createdAt;

  WallPost({
    required this.id,
    required this.content,
    this.responses,
    this.createdAt,
  });

  factory WallPost.fromJson(Map<String, dynamic> json) {
    return WallPost(
      id: json['id'],
      content: json['content'] ?? '',
      responses: json['responses'] != null
          ? (json['responses'] as List).map((r) => WallResponse.fromJson(r)).toList()
          : null,
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'responses': responses?.map((r) => r.toJson()).toList(),
      'created_at': createdAt,
    };
  }
}

class WallResponse {
  final String id;
  final String content;
  final String? createdAt;
  final bool isAdmin;
  final WallResponseAuthor? author;

  WallResponse({
    required this.id,
    required this.content,
    this.createdAt,
    required this.isAdmin,
    this.author,
  });

  factory WallResponse.fromJson(Map<String, dynamic> json) {
    return WallResponse(
      id: json['id'],
      content: json['content'] ?? '',
      createdAt: json['created_at'],
      isAdmin: json['is_admin'] ?? false,
      author: json['admin'] != null ? WallResponseAuthor.fromJson(json['admin']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt,
      'is_admin': isAdmin,
      'admin': author?.toJson(),
    };
  }
}

class WallResponseAuthor {
  final String id;
  final String? username;
  final String? fullName;
  final String? avatarUrl;

  WallResponseAuthor({
    required this.id,
    this.username,
    this.fullName,
    this.avatarUrl,
  });

  factory WallResponseAuthor.fromJson(Map<String, dynamic> json) {
    return WallResponseAuthor(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
    };
  }

  String get displayName => fullName ?? username ?? 'Admin';
}