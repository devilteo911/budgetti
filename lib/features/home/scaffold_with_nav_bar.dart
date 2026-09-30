import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/l10n/app_localizations.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/core/theme/glass.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/core/services/motion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:budgetti/core/widgets/app_sheet.dart';

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar>
    with WidgetsBindingObserver {
  late MotionService _motionService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _motionService = MotionService(onTwistDetected: _onTwistDetected);
    // Defer sensor subscription to after first frame to avoid blocking initial render
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _motionService.startListening();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motionService.stopListening();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _motionService.stopListening();
    } else if (state == AppLifecycleState.resumed) {
      _motionService.startListening();
    }
  }

  void _onTwistDetected() {
    // Only trigger if a modal is not already showing (optional but safer)
    if (!mounted) return;

    HapticFeedback.heavyImpact();

    _onAddTransaction(triggerScan: true);
  }

  void _onAddTransaction({bool triggerScan = false}) {
    showAppSheet(
      context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => AddTransactionModal(triggerScan: triggerScan),
    );
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return DockSnackBarTheme(
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // Body fills edge-to-edge behind the floating nav so glass has
            // real content to blur. Screens that want their last scroll item
            // fully visible above the pill should add ~120px bottom padding
            // to their own scrollable (ListView/CustomScrollView).
            Positioned.fill(child: widget.navigationShell),
            Positioned(
              left: 0,
              right: 0,
              bottom: bottomInset + DockMetrics.bottomGap,
              child: Center(
                child: FloatingPillNav(
                  slots: buildNavSlots(
                    context.l10n,
                    reviewCount: ref.watch(reviewInboxCountProvider),
                    onAdd: () {
                      HapticFeedback.mediumImpact();
                      _onAddTransaction();
                    },
                  ),
                  currentBranchIndex: currentIndex,
                  onBranchSelected: _goBranch,
                ),
              ),
            ),
            // Live backend-sync indicator, top-right, above all screens.
            Positioned(
              top: MediaQuery.of(context).viewPadding.top + 12,
              right: 16,
              child: ValueListenableBuilder<bool>(
                valueListenable: ref
                    .watch(pocketBaseSyncServiceProvider)
                    .syncing,
                builder: (context, syncing, _) =>
                    syncing ? const _SyncSpinner() : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A spinning sync arrow shown while data is being pushed/pulled from the
/// backend. Mounted only during a sync, so the animation stops when idle.
class _SyncSpinner extends StatefulWidget {
  const _SyncSpinner();

  @override
  State<_SyncSpinner> createState() => _SyncSpinnerState();
}

class _SyncSpinnerState extends State<_SyncSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      child: RotationTransition(
        turns: _controller,
        child: Icon(Icons.sync, size: 18, color: scheme.primary),
      ),
    );
  }
}

@visibleForTesting
class NavSlot {
  final int? branchIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback? onAction;

  /// Items waiting behind this slot; a badge shows when above zero.
  final int badge;

  /// What a screen reader adds to [label] when [badge] is showing.
  final String? badgeLabel;

  const NavSlot._({
    this.branchIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.onAction,
    this.badge = 0,
    this.badgeLabel,
  });

  factory NavSlot.branch(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    int badge = 0,
    String? badgeLabel,
  }) => NavSlot._(
    branchIndex: index,
    icon: icon,
    activeIcon: activeIcon,
    label: label,
    badge: badge,
    badgeLabel: badgeLabel,
  );

  factory NavSlot.action(IconData icon, String label, VoidCallback onTap) =>
      NavSlot._(icon: icon, activeIcon: icon, label: label, onAction: onTap);

  bool get isAction => onAction != null;
}

/// Where the floating dock sits, for every screen that scrolls underneath it.
abstract final class DockMetrics {
  /// Space between the pill and the bottom edge (above the gesture-bar inset).
  static const double bottomGap = 16;

  /// The pill's height: its items plus the glass container's vertical padding.
  /// Must equal [FloatingPillNav]'s rendered height (asserted in
  /// test/dock_clearance_test.dart).
  static const double height = 64;

  /// How much of a screen's bottom the dock covers, plus a little air. Every
  /// scrollable in the shell ends with this much padding, so its last row can be
  /// scrolled clear of the pill instead of ending underneath it.
  static double clearance(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom + bottomGap + height + 16;
}

/// Makes the snackbars of the scaffold below float above the dock instead of
/// across it. Screens inside the shell have nested scaffolds, and the messenger
/// shows a snackbar in the outermost one — ScaffoldWithNavBar's — which has no
/// bottom bar of its own to lift it, so the lift is the theme's inset.
class DockSnackBarTheme extends StatelessWidget {
  const DockSnackBarTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          // The scaffold already keeps a floating snackbar out of the gesture
          // inset, so only the dock itself is left to clear: its gap, its height,
          // and 8 dp of air above the pill.
          insetPadding: const EdgeInsets.fromLTRB(
            16,
            0,
            16,
            DockMetrics.bottomGap + DockMetrics.height + 8,
          ),
        ),
      ),
      child: child,
    );
  }
}

/// GitHub-Store-inspired floating pill bottom nav.
/// Glass capsule with an animated gradient indicator that slides behind
/// the selected branch. Action slots (e.g. '+') don't move the indicator.
@visibleForTesting
class FloatingPillNav extends StatelessWidget {
  final List<NavSlot> slots;
  final int currentBranchIndex;
  final ValueChanged<int> onBranchSelected;

  const FloatingPillNav({
    super.key,
    required this.slots,
    required this.currentBranchIndex,
    required this.onBranchSelected,
  });

  static const double _itemWidth = 62;
  static const double _itemHeight = 56;
  static const double _hPad = 6;

  /// The slot's Semantics label already carries the count in words; the badge's
  /// own "3" would be read a second time.
  ///
  /// Badge is a Stack that aligns its child top-start, so handed the cell's tight
  /// constraints it parked the glyph in the cell's corner. The Center gives it
  /// loose ones: the Badge shrinks to the glyph, which stays where an unbadged
  /// one sits, and the count only overlays its corner.
  static Widget _badged(int count, Widget icon) => count > 0
      ? Center(
          child: ExcludeSemantics(
            child: Badge.count(count: count, child: icon),
          ),
        )
      : icon;

  int? _slotIndexForBranch(int branchIndex) {
    for (var i = 0; i < slots.length; i++) {
      if (slots[i].branchIndex == branchIndex) return i;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalWidth = slots.length * _itemWidth + _hPad * 2;
    final activeSlotIndex = _slotIndexForBranch(currentBranchIndex) ?? 0;

    return GlassContainer(
      borderRadius: BorderRadius.circular(_itemHeight),
      tint: scheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: _hPad, vertical: 4),
      child: SizedBox(
        width: totalWidth,
        height: _itemHeight,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              left: activeSlotIndex * _itemWidth,
              top: 2,
              width: _itemWidth,
              height: _itemHeight - 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.primary.withValues(alpha: 0.28),
                      scheme.primary.withValues(alpha: 0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular((_itemHeight - 4) / 2),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
              ),
            ),
            Row(
              children: List.generate(slots.length, (i) {
                final s = slots[i];
                final selected =
                    !s.isAction && s.branchIndex == currentBranchIndex;
                return SizedBox(
                  width: _itemWidth,
                  height: _itemHeight,
                  child: Material(
                    color: Colors.transparent,
                    // The pill is icon-only, so the label a screen reader
                    // announces has to come from here.
                    child: Semantics(
                      label: s.badge > 0 && s.badgeLabel != null
                          ? '${s.label}, ${s.badgeLabel}'
                          : s.label,
                      button: true,
                      selected: selected,
                      child: InkWell(
                        onTap: () {
                          if (s.isAction) {
                            s.onAction!();
                          } else {
                            onBranchSelected(s.branchIndex!);
                          }
                        },
                        borderRadius: BorderRadius.circular(_itemHeight / 2),
                        child: AnimatedScale(
                          scale: selected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: _badged(
                            s.badge,
                            Icon(
                              selected ? s.activeIcon : s.icon,
                              color: selected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nav slots: 4 branches + the centre action. Branch indices map 1:1 to
/// StatefulShellRoute branches in app_router.dart. [reviewCount] — bank drafts
/// plus unreadable messages waiting in the review inbox — rides on History,
/// where the inbox banner lives.
@visibleForTesting
List<NavSlot> buildNavSlots(
  AppLocalizations l10n, {
  required int reviewCount,
  required VoidCallback onAdd,
}) => [
  NavSlot.branch(
    0,
    Icons.dashboard_outlined,
    Icons.dashboard,
    l10n.authNavDashboard,
  ),
  NavSlot.branch(
    1,
    Icons.receipt_long_outlined,
    Icons.receipt_long,
    l10n.authNavHistory,
    badge: reviewCount,
    badgeLabel: l10n.txReviewBannerCount(reviewCount),
  ),
  NavSlot.action(Icons.add, l10n.commonAdd, onAdd),
  NavSlot.branch(
    2,
    Icons.pie_chart_outline,
    Icons.pie_chart,
    l10n.authNavStats,
  ),
  NavSlot.branch(
    3,
    Icons.settings_outlined,
    Icons.settings,
    l10n.authNavSettings,
  ),
];
