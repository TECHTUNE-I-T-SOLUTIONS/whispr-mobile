import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReviewDetailScreen extends StatelessWidget {
  final Map<String, dynamic> post;
  const ReviewDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final status = (post['flagStatus'] ?? post['status'] ?? 'draft').toString();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeal Details'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(post['title'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Current status: $status'),
          const SizedBox(height: 12),
          if ((post['flagReason'] ?? '').toString().isNotEmpty) Text('Reason: ${post['flagReason']}'),
          if ((post['flagDescription'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Details: ${post['flagDescription']}'),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: post['slug'] == null
                ? null
                : () async {
                    await context.push('/reviews');
                  },
            child: const Text('Open Review Center'),
          ),
        ],
      ),
    );
  }
}
