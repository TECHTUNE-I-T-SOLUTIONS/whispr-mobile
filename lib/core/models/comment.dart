// Comment model for post comments
class Comment {
  final String id;
  final String postId;
  final String authorName;
  final String authorEmail;
  final String? authorWebsite;
  final String content;
  final String? status;
  final String? adminReply;
  final String? createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorName,
    required this.authorEmail,
    this.authorWebsite,
    required this.content,
    this.status,
    this.adminReply,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'],
      postId: json['post_id'],
      authorName: json['author_name'],
      authorEmail: json['author_email'],
      authorWebsite: json['author_website'],
      content: json['content'],
      status: json['status'],
      adminReply: json['admin_reply'],
      createdAt: json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_name': authorName,
      'author_email': authorEmail,
      'author_website': authorWebsite,
      'content': content,
      'status': status,
      'admin_reply': adminReply,
      'created_at': createdAt,
    };
  }
}