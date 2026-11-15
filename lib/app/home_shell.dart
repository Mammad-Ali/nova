import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/locale_provider.dart';
import '../core/theme/app_theme.dart';
import '../features/more/presentation/more_screen.dart';
import '../features/settings/settings_sheet.dart';
import '../features/speedtest/presentation/providers/speedtest_provider.dart';
import '../features/speedtest/presentation/screens/speedtest_screen.dart';
import '../features/traffic_monitor/presentation/screens/traffic_monitor_screen.dart';
import '../shell/compact_mode.dart';
import '../shell/compact_panel.dart';
import 'starfield_background.dart';

/// The tab on show: 0 speed test, 1 monitor, 2 more. A provider rather than
/// widget state, so a tap on a Mac widget can bring the speed test forward.
final homeTabProvider = NotifierProvider<HomeTabNotifier, int>(HomeTabNotifier.new);

class HomeTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void show(int index) => state = index;
}

/// The app shell: shared backdrop plus two tabs in a glass navigation bar.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _pages = [SpeedTestScreen(), TrafficMonitorScreen(), MoreScreen()];

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);

    // The monitor tab needs system traffic counters, which a browser has no
    // way to read — on the web the speed test is the whole app, so the tab
    // bar has nothing to switch between.
    final index = kIsWeb ? 0 : ref.watch(homeTabProvider);

    // In compact mode the window becomes a small panel under the menu-bar
    // icon: the same data, without tabs or a frame.
    if (ref.watch(compactModeProvider)) {
      return Scaffold(
        backgroundColor: AppColors.bg0,
        body: Stack(children: [StarfieldBackground(), CompactPanel()]),
      );
    }

    final shell = Scaffold(
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
              // On the web the speed test page sets its own width: one
              // column on a phone, two on a laptop or desktop screen.
              child: KeyedSubtree(
                key: ValueKey<int>(index),
                child: _pages[index],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: kIsWeb
          ? null
          : _GlassNavBar(
              index: index,
              items: [
                (Icons.speed_rounded, t.tabSpeed),
                (Icons.show_chart_rounded, t.tabMonitor),
                (Icons.apps_rounded, t.tabMore),
              ],
              onTap: ref.read(homeTabProvider.notifier).show,
            ),
    );

    // Android's back button steps back to the speed test before it leaves
    // Nova, as most apps' tabs do.
    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(homeTabProvider.notifier).show(0);
      },
      child: _desktop ? _withShortcuts(context, shell) : shell,
    );
  }

  static bool get _desktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// The keyboard on a Mac or PC: ⌘/Ctrl+1, 2, 3 for the tabs (each tab
  /// shows its shortcut on hover), ⌘/Ctrl+R to start or stop a test, and
  /// ⌘/Ctrl+, for the settings, where Mac apps keep them.
  ///
  /// Matched by where the key sits, not by the letter it types: with a
  /// Russian or Azerbaijani layout, the R key types "к" or "r"-less letters,
  /// and shortcuts matched by letter would never fire.
  Widget _withShortcuts(BuildContext context, Widget child) {
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final tabs = ref.read(homeTabProvider.notifier);

    void startOrStop() {
      final test = ref.read(speedTestControllerProvider.notifier);
      if (ref.read(speedTestControllerProvider).isRunning) {
        test.stop();
      } else {
        tabs.show(0);
        test.start();
      }
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final keys = HardwareKeyboard.instance;
        final command = mac ? keys.isMetaPressed : keys.isControlPressed;
        if (!command || keys.isAltPressed || keys.isShiftPressed) return KeyEventResult.ignored;
        final VoidCallback? action = switch (event.physicalKey) {
          PhysicalKeyboardKey.digit1 => () => tabs.show(0),
          PhysicalKeyboardKey.digit2 => () => tabs.show(1),
          PhysicalKeyboardKey.digit3 => () => tabs.show(2),
          PhysicalKeyboardKey.keyR => startOrStop,
          PhysicalKeyboardKey.comma => () => showSettingsSheet(context),
          _ => null,
        };
        if (action == null) return KeyEventResult.ignored;
        action();
        return KeyEventResult.handled;
      },
      child: child,
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.index,
    required this.items,
    required this.onTap,
  });

  final int index;

  /// Icon and label of each tab, in order.
  final List<(IconData, String)> items;
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
                border: Border.all(
                  color: AppColors.onGlass.withValues(alpha: 0.10),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth / items.length;
                  return Stack(
                    children: [
                      // One white pill that glides to the chosen tab, with a
                      // touch of overshoot, rather than one fading in place.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 420),
                        curve: const Cubic(0.3, 1.25, 0.45, 1),
                        left: width * index,
                        top: 0,
                        bottom: 0,
                        width: width,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      // The full height of the bar: each tab centres its
                      // label on the pill, and the whole tab takes the
                      // mouse and taps, not a strip along its top.
                      Positioned.fill(
                        child: Row(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              _NavItem(
                                selected: index == i,
                                icon: items[i].$1,
                                label: items[i].$2,
                                shortcut: _shortcutLabel(i),
                                onTap: () => onTap(i),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "⌘1" on a Mac, "Ctrl+1" on Windows and Linux; nothing on a phone.
  static String? _shortcutLabel(int i) => switch (defaultTargetPlatform) {
        TargetPlatform.macOS => '⌘${i + 1}',
        TargetPlatform.windows || TargetPlatform.linux => 'Ctrl+${i + 1}',
        _ => null,
      };
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;

  /// Its keyboard shortcut, shown on hover (desktop).
  final String? shortcut;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    // Black on the white pill; brighter under the mouse.
    final color = selected
        ? Colors.black
        : _hovered
            ? AppColors.onGlass
            : AppColors.textLo;

    Widget item = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        // A faint glass highlight under the mouse, for the other tabs.
        decoration: BoxDecoration(
          color: !selected && _hovered ? AppColors.onGlass.withValues(alpha: 0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The icon gives a small bounce as its tab is chosen.
            TweenAnimationBuilder<double>(
              key: ValueKey(selected),
              tween: Tween(begin: selected ? 0.7 : 1, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(widget.icon, key: ValueKey(color), size: 20, color: color),
              ),
            ),
            const SizedBox(width: 8),
            // Three tabs share a phone's width, and some languages have
            // long words for them: let a label shrink rather than overflow.
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
                child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.shortcut != null) {
      item = Tooltip(
        message: '${widget.label}   ${widget.shortcut}',
        waitDuration: const Duration(milliseconds: 600),
        child: item,
      );
    }
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: item,
      ),
    );
  }
}
