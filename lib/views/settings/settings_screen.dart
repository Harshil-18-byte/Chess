import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/board_themes.dart';
import '../../core/theme/app_typography.dart';
import '../credits_screen.dart';
import '../../services/settings_service.dart';
import '../../services/audio_service.dart';
import 'custom_suite_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final render3d = ref.watch(render3dProvider);
    final reduceMotion = ref.watch(reduceMotionProvider);
    final pushEnabled = ref.watch(pushEnabledProvider);
    final audioService = ref.watch(audioServiceProvider);
    
    final user = FirebaseAuth.instance.currentUser;
    final isAnonymous = user?.isAnonymous ?? false;
    return Scaffold(
      backgroundColor: BoardThemes.scaffoldBackground,
      appBar: AppBar(
        title: Text('SETTINGS', style: AppTypography.titleMedium),
        backgroundColor: BoardThemes.surfaceDark,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Center(
            child: Text(
              'BACK',
              style: TextStyle(
                color: BoardThemes.pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Preferences'),
          _buildToggleItem('Render Mode (2D / 3D)', render3d, (v) {
            ref.read(render3dProvider.notifier).setRender3d(v);
          }),
          _buildToggleItem('Push Notifications', pushEnabled, (v) {
            ref.read(pushEnabledProvider.notifier).setPushEnabled(v);
          }),
          _buildToggleItem('Sound Effects', !audioService.isMuted, (v) {
            audioService.toggleMute();
            setState(() {});
          }),
          _buildToggleItem('Reduce Motion & Transparency', reduceMotion, (v) {
            ref.read(reduceMotionProvider.notifier).setReduceMotion(v);
          }),
          const SizedBox(height: 24),
          _buildSectionHeader('Customization'),
          _buildActionItem('Custom Suite (Themes & Board)', () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomSuiteScreen()),
            );
          }),
          const SizedBox(height: 24),
          _buildSectionHeader('Account & About'),
          _buildActionItem('View Credits', () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreditsScreen()),
            );
          }),
          if (isAnonymous)
            _buildActionItem('Upgrade Anonymous Account', () {
              // Implementation would link a credential
            }),
          _buildActionItem('Sign Out', () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          }),
          _buildActionItem('Delete Account', () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: BoardThemes.surfaceDark,
                title: const Text('Delete Account', style: TextStyle(color: BoardThemes.pureWhite)),
                content: const Text('Are you sure you want to permanently delete your account?', style: TextStyle(color: BoardThemes.mutedSilver)),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('CANCEL', style: TextStyle(color: BoardThemes.pureWhite))),
                  TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('DELETE', style: TextStyle(color: BoardThemes.dangerAlert))),
                ],
              ),
            );
            if (confirm == true) {
              try {
                await user?.delete();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (_) {}
            }
          }, isDanger: true),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: BoardThemes.mutedSilver,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildToggleItem(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: BoardThemes.surfaceCard,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: BoardThemes.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: BoardThemes.pureWhite)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: BoardThemes.pureWhite,
            activeTrackColor: BoardThemes.neutralGray,
            inactiveThumbColor: BoardThemes.mutedSilver,
            inactiveTrackColor: BoardThemes.darkCharcoal,
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(String label, VoidCallback onTap, {bool isDanger = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        decoration: BoxDecoration(
          color: BoardThemes.surfaceCard,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: BoardThemes.borderSubtle),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDanger ? BoardThemes.pitchBlack : BoardThemes.pureWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
