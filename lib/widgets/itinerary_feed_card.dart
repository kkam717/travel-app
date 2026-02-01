import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/itinerary.dart';
import 'static_map_image.dart';

/// Feed-style itinerary card. Supports optional author row, bookmark, and edit button.
class ItineraryFeedCard extends StatelessWidget {
  final Itinerary itinerary;
  final String description;
  final String locations;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback? onBookmark;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onEdit;

  const ItineraryFeedCard({
    super.key,
    required this.itinerary,
    required this.description,
    required this.locations,
    this.isBookmarked = false,
    required this.onTap,
    this.onBookmark,
    this.onAuthorTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final it = itinerary;
    const mapHeight = 200.0;

    return Card(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, AppTheme.spacingMd),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (onAuthorTap != null && (it.authorName != null || it.authorPhotoUrl != null))
                        Expanded(
                          child: InkWell(
                            onTap: onAuthorTap,
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: it.authorPhotoUrl != null && it.authorPhotoUrl!.isNotEmpty
                                      ? NetworkImage(it.authorPhotoUrl!)
                                      : null,
                                  child: it.authorPhotoUrl == null || it.authorPhotoUrl!.isEmpty
                                      ? Icon(Icons.person_outline_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    it.authorName ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (onBookmark != null)
                        IconButton(
                          icon: Icon(
                            isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: isBookmarked ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onPressed: onBookmark,
                          style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                        ),
                      if (onEdit != null)
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          onPressed: onEdit,
                          style: IconButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 40)),
                        ),
                    ],
                  ),
                  if (it.bookmarkCount != null && it.bookmarkCount! > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${it.bookmarkCount} saved',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                    ),
                  ],
                  if (it.updatedAt != null) ...[
                    const SizedBox(height: 2),
                    Text(_formatDate(it.updatedAt!), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: AppTheme.spacingSm),
                  Text(
                    it.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: AppTheme.spacingMd),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('${it.daysCount} days', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      if (it.mode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: it.mode == 'luxury' ? Colors.purple.shade50 : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            it.mode!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: it.mode == 'luxury' ? Colors.purple.shade700 : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      if (locations.isNotEmpty)
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: contentWidth - 100),
                          child: Text(
                            locations,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: StaticMapImage(
                      itinerary: it,
                      width: contentWidth,
                      height: mapHeight,
                      pathColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
