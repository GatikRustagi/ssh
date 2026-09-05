import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/supabase/supabase_client.dart';

final twitterPostsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final supabase = SupabaseClientWrapper.client;
  // Platform ID for X (Twitter)
  const twitterPlatformId = '11111111-0000-0000-0000-000000000001';
  
  final response = await supabase
      .from('posts')
      .select('*, authors(*)')
      .eq('platform_id', twitterPlatformId)
      .order('posted_at', ascending: false);
      
  return List<Map<String, dynamic>>.from(response);
});

class TwitterDetailsScreen extends ConsumerWidget {
  const TwitterDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(twitterPostsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Twitter Raw Data', style: TextStyle(color: AppTheme.textPrimary)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: AppTheme.border, height: 1),
        ),
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (error, stack) => Center(
          child: Text('Error loading tweets: $error', style: const TextStyle(color: AppTheme.sentimentNegative)),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const Center(
              child: Text(
                'No tweets found. Run the scraper first.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final post = posts[index];
              final author = post['authors'] ?? {};
              
              final handle = author['handle'] ?? 'Unknown';
              final displayName = author['display_name'] ?? handle;
              final content = post['content_text'] ?? '';
              final engagement = post['raw_engagement_count'] ?? 0;
              final postedAt = post['posted_at'] != null 
                  ? DateTime.parse(post['posted_at']).toLocal().toString().split('.')[0]
                  : 'Unknown Date';
              final url = post['url'];

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.accentLight),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '@$handle • $postedAt',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (url != null)
                          IconButton(
                            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: AppTheme.textSecondary),
                            onPressed: () async {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: const TextStyle(color: AppTheme.textPrimary, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.favorite_border_rounded, size: 16, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text('$engagement', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
