import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';
import 'location_with_flag.dart';

/// Number formatter: 1234 → "1.2k", 12345 → "12k", 850 → "850".
String _formatStatCount(int count) {
  if (count >= 10000) return '${(count / 1000).toStringAsFixed(0)}k';
  if (count >= 1000) {
    final k = count / 1000;
    final formatted = k.toStringAsFixed(1);
    // Strip trailing ".0"
    return formatted.endsWith('.0')
        ? '${formatted.substring(0, formatted.length - 2)}k'
        : '${formatted}k';
  }
  return count.toString();
}

/// Hero card for the profile screen – rounded white card with:
/// - Centered avatar (protrudes above the card top edge)
/// - Display name (large, centered)
/// - Flag emoji + current city (centered)
/// - 3-column stats row: Visited | Inspired | Following
/// - Small "Edit Profile" pencil icon (top-right inside the card)
class ProfileHeroCard extends StatelessWidget {
  final String? photoUrl;
  final bool isUploadingPhoto;
  final VoidCallback? onAvatarTap;
  final String? displayName;
  final String? currentCity;
  final VoidCallback? onCityTap;
  final int visitedCount;
  final int inspiredCount;
  final int followingCount;
  final VoidCallback? onVisitedTap;
  final VoidCallback? onInspiredTap;
  final VoidCallback? onFollowingTap;

  /// Edit profile popup items and handler (reuses existing menu logic).
  /// Optional – omit for author/view-profile screens.
  final List<PopupMenuEntry<String>>? editProfileMenuItems;
  final void Function(String?)? onEditProfileSelected;

  /// Optional trailing widget shown top-right (e.g. follow pill for author view).
  /// When set, replaces the edit profile icon.
  final Widget? trailingAction;

  static const double avatarRadius = 44.0;
  static const double avatarRingWidth = 3.0;

  const ProfileHeroCard({
    super.key,
    this.photoUrl,
    this.isUploadingPhoto = false,
    this.onAvatarTap,
    this.displayName,
    this.currentCity,
    this.onCityTap,
    required this.visitedCount,
    required this.inspiredCount,
    required this.followingCount,
    this.onVisitedTap,
    this.onInspiredTap,
    this.onFollowingTap,
    this.editProfileMenuItems,
    this.onEditProfileSelected,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.brightness == Brightness.light
        ? Colors.white
        : theme.colorScheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Card content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, avatarRadius + 14, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Display name
                Text(
                  displayName ?? AppStrings.t(context, 'profile'),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: -0.3,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Flag + City name (centered)
                GestureDetector(
                  onTap: onCityTap,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LocationFlagIcon(
                        city: currentCity?.trim().isNotEmpty == true
                            ? currentCity
                            : null,
                        fontSize: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentCity?.trim().isNotEmpty == true
                            ? currentCity!
                            : AppStrings.t(context, 'not_set'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 3-column stats row
                _StatsRow(
                  visitedCount: visitedCount,
                  inspiredCount: inspiredCount,
                  followingCount: followingCount,
                  onVisitedTap: onVisitedTap,
                  onInspiredTap: onInspiredTap,
                  onFollowingTap: onFollowingTap,
                ),
              ],
            ),
          ),

          // Avatar – centered at top, protruding above card, with "+" button
          Positioned(
            top: -avatarRadius,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: isUploadingPhoto ? null : onAvatarTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cardColor,
                          width: avatarRingWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            backgroundImage:
                                photoUrl != null && photoUrl!.isNotEmpty
                                    ? NetworkImage(photoUrl!)
                                    : null,
                            child: photoUrl == null || photoUrl!.isEmpty
                                ? Icon(
                                    Icons.person_outline,
                                    size: avatarRadius,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                          if (isUploadingPhoto)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Small "+" button at bottom-right of the avatar
                    if (onAvatarTap != null)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surfaceContainerHighest,
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.shadow.withValues(alpha: 0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: isUploadingPhoto
                              ? Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Icon(Icons.add,
                                  size: 18,
                                  color: theme.colorScheme.onSurface),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Top-right action: edit menu, custom trailing, or nothing
          if (trailingAction != null)
            Positioned(
              top: 10,
              right: 10,
              child: trailingAction!,
            )
          else if (editProfileMenuItems != null && onEditProfileSelected != null)
            Positioned(
              top: 10,
              right: 10,
              child: PopupMenuButton<String>(
                onSelected: onEditProfileSelected,
                itemBuilder: (_) => editProfileMenuItems!,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three-column stats row: Visited | Inspired | Following
/// Big number, small uppercase label below, thin vertical dividers.
class _StatsRow extends StatelessWidget {
  final int visitedCount;
  final int inspiredCount;
  final int followingCount;
  final VoidCallback? onVisitedTap;
  final VoidCallback? onInspiredTap;
  final VoidCallback? onFollowingTap;

  const _StatsRow({
    required this.visitedCount,
    required this.inspiredCount,
    required this.followingCount,
    this.onVisitedTap,
    this.onInspiredTap,
    this.onFollowingTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              value: _formatStatCount(visitedCount),
              label: AppStrings.t(context, 'visited').toUpperCase(),
              onTap: onVisitedTap,
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          Expanded(
            child: _StatColumn(
              value: _formatStatCount(inspiredCount),
              label: AppStrings.t(context, 'inspired').toUpperCase(),
              onTap: onInspiredTap,
            ),
          ),
          VerticalDivider(width: 1, thickness: 1, color: dividerColor),
          Expanded(
            child: _StatColumn(
              value: _formatStatCount(followingCount),
              label: AppStrings.t(context, 'following').toUpperCase(),
              onTap: onFollowingTap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Single stat column: big number + small uppercase label.
class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatColumn({
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }
}
