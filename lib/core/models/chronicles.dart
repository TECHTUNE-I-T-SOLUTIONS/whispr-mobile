enum PostType { blog, poem }

enum PostStatus { draft, published, archived }

enum EngagementAction { like, comment, share }

enum NotificationType {
  postLike,
  postComment,
  newFollower,
  engagementMilestone,
  newCreatorSignup
}

enum ProfileVisibility { public, private }

class Creator {
  final String id;
  final String? userId;
  final String email;
  final String penName;
  final String displayName;
  final String bio;
  final String? profileImageUrl;
  final PostType contentType;
  final List<String> categories;
  final Map<String, String> socialLinks;
  final ProfileVisibility profileVisibility;
  final bool pushNotificationsEnabled;
  final int postCount;
  final int engagementCount;
  final int currentStreak;
  final int totalPoints;
  final bool verifiedBadge;
  final String? lastActivityAt;
  final String? createdAt;
  final String? updatedAt;
  // Additional profile fields
  final int totalFollowers;
  final int totalBlogs;
  final int totalPoems;
  final int totalEngagement;
  final String? location;
  final String? website;
  final String? status;
  final List<String> badges;
  final String role;

  Creator({
    required this.id,
    required this.userId,
    required this.email,
    required this.penName,
    required this.displayName,
    required this.bio,
    this.profileImageUrl,
    required this.contentType,
    required this.categories,
    required this.socialLinks,
    required this.profileVisibility,
    required this.pushNotificationsEnabled,
    required this.postCount,
    required this.engagementCount,
    required this.currentStreak,
    required this.totalPoints,
    required this.verifiedBadge,
    required this.lastActivityAt,
    required this.createdAt,
    required this.updatedAt,
    this.totalFollowers = 0,
    this.totalBlogs = 0,
    this.totalPoems = 0,
    this.totalEngagement = 0,
    this.location,
    this.website,
    this.status,
    this.badges = const [],
    this.role = 'creator',
  });

  factory Creator.fromJson(Map<String, dynamic> json) {
    return Creator(
      id: json['id'],
      userId: json['user_id'] ?? json['id'], // fallback to id if user_id not provided
      email: json['email'],
      penName: json['penName'] ?? json['pen_name'],
      displayName: json['displayName'] ?? json['display_name'] ?? json['penName'] ?? json['pen_name'],
      bio: json['bio'] ?? '',
      profileImageUrl: json['profileImageUrl'] ?? json['profile_image_url'] ?? json['avatarUrl'] ?? json['avatar_url'] ?? json['profile_picture_url'] ?? json['profileImage'],
      contentType: PostType.values.firstWhere(
        (e) => e.name == (json['content_type'] ?? 'both'),
        orElse: () => PostType.blog,
      ),
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : (json['preferred_categories'] != null ? List<String>.from(json['preferred_categories']) : []),
      socialLinks: json['social_links'] != null
          ? Map<String, String>.from(json['social_links'])
          : {},
      profileVisibility: ProfileVisibility.values.firstWhere(
        (e) => e.name == (json['profile_visibility'] ?? 'public'),
        orElse: () => ProfileVisibility.public,
      ),
      pushNotificationsEnabled: json['push_notifications_enabled'] ?? true,
      postCount: json['post_count'] ?? json['total_posts'] ?? 0,
      engagementCount: json['engagement_count'] ?? json['total_engagement'] ?? 0,
      currentStreak: json['current_streak'] ?? json['streak_count'] ?? 0,
      totalPoints: json['total_points'] ?? 0,
      verifiedBadge: json['verified_badge'] ?? json['is_verified'] ?? false,
      lastActivityAt: json['last_activity_at'] ?? json['updated_at'] ?? DateTime.now().toIso8601String(),
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] ?? DateTime.now().toIso8601String(),
      totalFollowers: json['total_followers'] ?? 0,
      totalBlogs: json['total_blog_posts'] ?? 0,
      totalPoems: json['total_poems'] ?? 0,
      totalEngagement: json['total_engagement'] ?? 0,
      location: json['location'],
      website: json['website'] ?? json['social_links']?['website'],
      status: json['status'] ?? 'active',
      badges: json['badges'] != null ? List<String>.from(json['badges']) : [],
      role: json['role'] ?? 'creator',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'email': email,
      'pen_name': penName,
      'display_name': displayName,
      'bio': bio,
      'profile_image_url': profileImageUrl,
      'content_type': contentType.name,
      'categories': categories,
      'social_links': socialLinks,
      'profile_visibility': profileVisibility.name,
      'push_notifications_enabled': pushNotificationsEnabled,
      'post_count': postCount,
      'engagement_count': engagementCount,
      'current_streak': currentStreak,
      'total_points': totalPoints,
      'verified_badge': verifiedBadge,
      'last_activity_at': lastActivityAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  Creator copyWith({
    String? id,
    String? userId,
    String? email,
    String? penName,
    String? displayName,
    String? bio,
    String? profileImageUrl,
    PostType? contentType,
    List<String>? categories,
    Map<String, String>? socialLinks,
    ProfileVisibility? profileVisibility,
    bool? pushNotificationsEnabled,
    int? postCount,
    int? engagementCount,
    int? currentStreak,
    int? totalPoints,
    bool? verifiedBadge,
    String? lastActivityAt,
    String? createdAt,
    String? updatedAt,
    int? totalFollowers,
    int? totalBlogs,
    int? totalPoems,
    int? totalEngagement,
    String? location,
    String? website,
    String? status,
    List<String>? badges,
    String? role,
  }) {
    return Creator(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      penName: penName ?? this.penName,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      contentType: contentType ?? this.contentType,
      categories: categories ?? this.categories,
      socialLinks: socialLinks ?? this.socialLinks,
      profileVisibility: profileVisibility ?? this.profileVisibility,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      postCount: postCount ?? this.postCount,
      engagementCount: engagementCount ?? this.engagementCount,
      currentStreak: currentStreak ?? this.currentStreak,
      totalPoints: totalPoints ?? this.totalPoints,
      verifiedBadge: verifiedBadge ?? this.verifiedBadge,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      totalFollowers: totalFollowers ?? this.totalFollowers,
      totalBlogs: totalBlogs ?? this.totalBlogs,
      totalPoems: totalPoems ?? this.totalPoems,
      totalEngagement: totalEngagement ?? this.totalEngagement,
      location: location ?? this.location,
      website: website ?? this.website,
      status: status ?? this.status,
      badges: badges ?? this.badges,
      role: role ?? this.role,
    );
  }
}

class ChroniclesPost {
  final String id;
  final String creatorId;
  final String title;
  final String slug;
  final String excerpt;
  final String content;
  final PostType postType;
  final String category;
  final List<String> tags;
  final String? coverImageUrl;
  final Map<String, dynamic>? formattingData;
  final PostStatus status;
  final int viewCount;
  final int engagementCount;
  final String? scheduledFor;
  final String createdAt;
  final String updatedAt;
  final String? publishedAt;
  final Creator? creator;

  ChroniclesPost({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.slug,
    required this.excerpt,
    required this.content,
    required this.postType,
    required this.category,
    required this.tags,
    this.coverImageUrl,
    this.formattingData,
    required this.status,
    required this.viewCount,
    required this.engagementCount,
    this.scheduledFor,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
    this.creator,
  });

  factory ChroniclesPost.fromJson(Map<String, dynamic> json) {
    return ChroniclesPost(
      id: json['id'],
      creatorId: json['creator_id'],
      title: json['title'],
      slug: json['slug'],
      excerpt: json['excerpt'],
      content: json['content'],
      postType: PostType.values.firstWhere(
        (e) => e.name == json['post_type'],
        orElse: () => PostType.blog,
      ),
      category: json['category'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      coverImageUrl: json['cover_image_url'],
      formattingData: json['formatting_data'],
      status: PostStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PostStatus.draft,
      ),
      viewCount: json['view_count'] ?? 0,
      engagementCount: json['engagement_count'] ?? 0,
      scheduledFor: json['scheduled_for'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      publishedAt: json['published_at'],
      creator: json['creator'] != null ? Creator.fromJson(json['creator']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'slug': slug,
      'excerpt': excerpt,
      'content': content,
      'post_type': postType.name,
      'category': category,
      'tags': tags,
      'cover_image_url': coverImageUrl,
      'formatting_data': formattingData,
      'status': status.name,
      'view_count': viewCount,
      'engagement_count': engagementCount,
      'scheduled_for': scheduledFor,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'published_at': publishedAt,
      'creator': creator?.toJson(),
    };
  }
}

class Engagement {
  final String id;
  final String postId;
  final String creatorId;
  final EngagementAction action;
  final String? commentText;
  final String createdAt;

  Engagement({
    required this.id,
    required this.postId,
    required this.creatorId,
    required this.action,
    this.commentText,
    required this.createdAt,
  });

  factory Engagement.fromJson(Map<String, dynamic> json) {
    return Engagement(
      id: json['id'],
      postId: json['post_id'],
      creatorId: json['creator_id'],
      action: EngagementAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => EngagementAction.like,
      ),
      commentText: json['comment_text'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'creator_id': creatorId,
      'action': action.name,
      'comment_text': commentText,
      'created_at': createdAt,
    };
  }
}

class WhisprWallPost {
  final String id;
  final String content;
  final String? createdAt;

  WhisprWallPost({
    required this.id,
    required this.content,
    this.createdAt,
  });

  factory WhisprWallPost.fromJson(Map<String, dynamic> json) {
    return WhisprWallPost(
      id: json['id'],
      content: json['content'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'created_at': createdAt,
    };
  }
}

class WritingChain {
  final String id;
  final String title;
  final String? description;
  final String createdAt;
  final int entriesCount;

  WritingChain({
    required this.id,
    required this.title,
    this.description,
    required this.createdAt,
    required this.entriesCount,
  });

  factory WritingChain.fromJson(Map<String, dynamic> json) {
    return WritingChain(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      createdAt: json['created_at'],
      entriesCount: json['entries'] is List && json['entries'].isNotEmpty
          ? json['entries'][0]['count'] ?? 0
          : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'created_at': createdAt,
      'entries_count': entriesCount,
    };
  }

  String get createdAtFormatted {
    try {
      final date = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'today';
      } else if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks week${weeks == 1 ? '' : 's'} ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '$months month${months == 1 ? '' : 's'} ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return '$years year${years == 1 ? '' : 's'} ago';
      }
    } catch (e) {
      return createdAt;
    }
  }
}