import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/speedtest/presentation/screens/speedtest_screen.dart';
import '../features/traffic_monitor/presentation/screens/traffic_monitor_screen.dart';
import '../shell/compact_mode.dart';
import '../shell/compact_panel.dart';
import 'starfield_background.dart';

/// The app shell: shared backdrop plus two tabs in a glass navigation bar.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _pages = [SpeedTestScreen(), TrafficMonitorScreen()];

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);

    // In compact mode the window becomes a small panel under the menu-bar
    // icon: the same data, without tabs or a frame.
    if (ref.watch(compactModeProvider)) {
      return Scaffold(
        backgroundColor: AppColors.bg0,
        body: Stack(
          children: [
            StarfieldBackground(),
            CompactPanel(),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bg0,
      body: Stack(
        children: [
          const StarfieldBackground(),
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey<int>(_index),
                child: _pages[_index],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GlassNavBar(
        index: _index,
        speedLabel: t.tabSpeed,
        monitorLabel: t.tabMonitor,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.index,
    required this.speedLabel,
    required this.monitorLabel,
    required this.onTap,
  });

  final int index;
  final String speedLabel;
  final String monitorLabel;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.onGlass.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.onGlass.withValues(alpha: 0.10)),
              ),
              child: Row(
                children: [
                  _NavItem(
                    selected: index == 0,
                    icon: Icons.speed_rounded,
                    label: speedLabel,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    selected: index == 1,
                    icon: Icons.show_chart_rounded,
                    label: monitorLabel,
                    onTap: () => onTap(1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          // The active tab is a white pill with black text and no glow.
          decoration: BoxDecoration(
            color: selected ? Colors.white : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? Colors.black : AppColors.textLo,
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 260),
                style: TextStyle(
                  color: selected ? Colors.black : AppColors.textLo,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
