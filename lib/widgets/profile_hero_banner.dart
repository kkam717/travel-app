import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'profile_banner_2026.dart';

/// Hero section: banner, scrim, top icons, avatar, then Column with name → info row, then stats pinned to bottom.
/// Uses spaceBetween so stats never overlap name/info; no overflow.
const double kProfileHeroBannerHeight = 360;

// Layout constants (fit within 320–360px hero)
const double _heroAvatarSize = 96.0;
const double _heroAvatarTopPadding = 12.0;
const double _heroSpacingAvatarToContent = 10.0;
const double _heroHorizontalPadding = 20.0;
const double _heroContentBottomPadding = 12.0;

class ProfileHeroBanner extends StatelessWidget {
  final String? currentCity;
  final String? coverImageUrl;
  /// Asset path for a local banner image (e.g. 'assets/images/profile_banner_london.png').
  final String? coverImageAsset;
  final String seedKey;
  final String? name;
  final String? photoUrl;
  final VoidCallback? onQrTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onEditProfileTap;
  /// When set, the Edit profile pill becomes a popup menu; options open from the button.
  final List<PopupMenuEntry<String>>? editProfileMenuItems;
  final void Function(String?)? onEditProfileMenuSelected;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onCityTap;
  final bool isUploadingPhoto;
  final Widget? statTilesRow;
  final String editProfileLabel;
  /// When set (e.g. back button), shown at top left. Used for author profile.
  final Widget? leadingWidget;
  /// When set, shown instead of Edit profile pill (e.g. Follow button for author).
  final Widget? actionPill;
  /// When false, only QR is shown in top right (no Settings). Used for author profile.
  final bool showSettingsIcon;

  const ProfileHeroBanner({
    super.key,
    this.currentCity,
    this.coverImageUrl,
    this.coverImageAsset,
    required this.seedKey,
    this.name,
    this.photoUrl,
    this.onQrTap,
    this.onSettingsTap,
    this.onEditProfileTap,
    this.editProfileMenuItems,
    this.onEditProfileMenuSelected,
    this.onAvatarTap,
    this.onCityTap,
    this.isUploadingPhoto = false,
    this.statTilesRow,
    this.editProfileLabel = 'Edit profile',
    this.leadingWidget,
    this.actionPill,
    this.showSettingsIcon = true,
  });

  static String _initials(String? n) {
    if (n == null || n.trim().isEmpty) return '?';
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.length >= 2 ? parts.first.substring(0, 2).toUpperCase() : parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final avatarTop = topInset + _heroAvatarTopPadding;
    final contentTop = avatarTop + _heroAvatarSize + _heroSpacingAvatarToContent;

    return SizedBox(
      height: kProfileHeroBannerHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1) Background banner
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              child: ProfileBanner2026(
                currentCity: currentCity,
                coverImageUrl: coverImageUrl,
                coverImageAsset: coverImageAsset,
                seedKey: seedKey,
                height: kProfileHeroBannerHeight,
                bottomRadius: 28,
                enableShimmer: false,
              ),
            ),
          ),
          // 2) Scrim: warm, dark at top for readability; gradient so text never on raw photo
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.black.withValues(alpha: 0.25),
                    Color.lerp(Colors.black, const Color(0xFF2D1B0E), 0.3)!.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  stops: const [0.0, 0.3, 0.6, 0.85],
                ),
              ),
            ),
          ),
          // 2b) Bottom fade: blend banner into page background (no hard edge)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                    Theme.of(context).colorScheme.surface,
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),
          // 3) Avatar only (positioned; does not participate in Column)
          Positioned(
            left: _heroHorizontalPadding,
            top: avatarTop,
            child: GestureDetector(
              onTap: onAvatarTap,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: _heroAvatarSize / 2,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                          ? NetworkImage(photoUrl!)
                          : null,
                      child: photoUrl == null || photoUrl!.isEmpty
                          ? Text(
                              _initials(name),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            )
                          : null,
                    ),
                  ),
                  if (isUploadingPhoto)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 5) Content: spacer pushes name + Edit profile to bottom of space above badges, then stats
          Positioned(
            left: _heroHorizontalPadding,
            right: _heroHorizontalPadding,
            top: contentTop,
            bottom: _heroContentBottomPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // Name + Edit profile at bottom of space above the badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name?.trim().isNotEmpty == true ? name! : 'Profile',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black.withValues(alpha: 0.7), offset: const Offset(0, 1), blurRadius: 6),
                            Shadow(color: Colors.black.withValues(alpha: 0.5), offset: const Offset(0, 2), blurRadius: 8),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (actionPill != null)
                      actionPill!
                    else if (editProfileMenuItems != null && onEditProfileMenuSelected != null)
                      PopupMenuButton<String>(
                        offset: const Offset(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Theme.of(context).colorScheme.surfaceContainerHigh,
                        onSelected: onEditProfileMenuSelected,
                        itemBuilder: (_) => editProfileMenuItems!,
                        child: Material(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  editProfileLabel,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Material(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(999),
                        child: InkWell(
                          onTap: onEditProfileTap,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.edit_outlined, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  editProfileLabel,
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (statTilesRow != null) statTilesRow!,
              ],
            ),
          ),
          // Top bar on top layer (above avatar): back button + QR/Settings
          if (leadingWidget != null)
            Positioned(
              top: topInset + 8,
              left: 8,
              child: leadingWidget!,
            ),
          Positioned(
            top: topInset + 8,
            right: 8,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: const Icon(Icons.qr_code_2_outlined, size: 24),
                  onPressed: onQrTap,
                  color: Colors.white,
                ),
                if (showSettingsIcon)
                  IconButton(
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    icon: const Icon(Icons.settings_outlined, size: 24),
                    onPressed: onSettingsTap,
                    color: Colors.white,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
