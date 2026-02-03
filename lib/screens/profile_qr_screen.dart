import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme.dart';
import '../core/app_link.dart';
import '../l10n/app_strings.dart';

/// Revolut-style screen: "My code" (user's profile QR + share) and "Scan" (camera to scan another user's QR).
class ProfileQRScreen extends StatefulWidget {
  final String userId;
  final String? userName;

  const ProfileQRScreen({super.key, required this.userId, this.userName});

  @override
  State<ProfileQRScreen> createState() => _ProfileQRScreenState();
}

class _ProfileQRScreenState extends State<ProfileQRScreen> {
  static const int _tabMyCode = 0;
  static const int _tabScan = 1;
  int _selectedTab = _tabMyCode;

  void _onScanned(String raw) {
    String path = raw;
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.path.isNotEmpty) path = uri.path;
    if (!path.startsWith('/')) path = '/$path';
    final match = RegExp(r'^/author/([a-f0-9-]+)$', caseSensitive: false).firstMatch(path);
    if (match != null) {
      final authorId = match.group(1)!;
      if (!mounted) return;
      context.pop();
      context.push('/author/$authorId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(widget.userName ?? AppStrings.t(context, 'my_code')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedTab == _tabMyCode
                ? _buildMyCodeContent()
                : _buildScanContent(),
          ),
          _buildTabBar(),
        ],
      ),
    );
  }

  Widget _buildMyCodeContent() {
    final link = profileShareLink(widget.userId);
    final name = widget.userName ?? AppStrings.t(context, 'profile');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacingLg),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: link,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Theme.of(context).colorScheme.surface,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacingLg),
          Text(
            name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
            child: Text(
              AppStrings.t(context, 'scan_to_view_profile'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXl),
          OutlinedButton.icon(
            onPressed: () => shareProfileLink(widget.userId, name: widget.userName),
            icon: const Icon(Icons.share_outlined, size: 20),
            label: Text(AppStrings.t(context, 'share_link')),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            facing: CameraFacing.back,
            torchEnabled: false,
          ),
          onDetect: (capture) {
            final barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              final raw = barcode.rawValue;
              if (raw != null && raw.isNotEmpty) {
                _onScanned(raw);
                return;
              }
            }
          },
        ),
        SafeArea(
          child: Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.spacingLg, 0, AppTheme.spacingLg, AppTheme.spacingMd),
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                label: AppStrings.t(context, 'scan'),
                isSelected: _selectedTab == _tabScan,
                onTap: () => setState(() => _selectedTab = _tabScan),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TabButton(
                label: AppStrings.t(context, 'my_code'),
                isSelected: _selectedTab == _tabMyCode,
                onTap: () => setState(() => _selectedTab = _tabMyCode),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
