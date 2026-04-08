import 'package:budgetti/core/theme/glass.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/core/services/motion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      barrierColor: Colors.black54,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => AddTransactionModal(triggerScan: triggerScan),
    );
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  // Nav slots: 4 branches + center action. Branch indices map 1:1 to
  // StatefulShellRoute branches in app_router.dart.
  List<_NavSlot> _buildSlots() => [
        _NavSlot.branch(
            0, Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
        _NavSlot.branch(
            1, Icons.receipt_long_outlined, Icons.receipt_long, 'History'),
        _NavSlot.action(Icons.add, 'Add', () {
          HapticFeedback.mediumImpact();
          _onAddTransaction();
        }),
        _NavSlot.branch(
            2, Icons.pie_chart_outline, Icons.pie_chart, 'Stats'),
        _NavSlot.branch(
            3, Icons.settings_outlined, Icons.settings, 'Settings'),
      ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
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
            bottom: bottomInset + 16,
            child: Center(
              child: _FloatingPillNav(
                slots: _buildSlots(),
                currentBranchIndex: currentIndex,
                onBranchSelected: _goBranch,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _NavSlot {
  final int? branchIndex;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback? onAction;

  const _NavSlot._({
    this.branchIndex,
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.onAction,
  });

  factory _NavSlot.branch(
          int index, IconData icon, IconData activeIcon, String label) =>
      _NavSlot._(
        branchIndex: index,
        icon: icon,
        activeIcon: activeIcon,
        label: label,
      );

  factory _NavSlot.action(IconData icon, String label, VoidCallback onTap) =>
      _NavSlot._(
        icon: icon,
        activeIcon: icon,
        label: label,
        onAction: onTap,
      );

  bool get isAction => onAction != null;
}

/// GitHub-Store-inspired floating pill bottom nav.
/// Glass capsule with an animated gradient indicator that slides behind
/// the selected branch. Action slots (e.g. '+') don't move the indicator.
class _FloatingPillNav extends StatelessWidget {
  final List<_NavSlot> slots;
  final int currentBranchIndex;
  final ValueChanged<int> onBranchSelected;

  const _FloatingPillNav({
    required this.slots,
    required this.currentBranchIndex,
    required this.onBranchSelected,
  });

  static const double _itemWidth = 62;
  static const double _itemHeight = 56;
  static const double _hPad = 6;

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
                  borderRadius:
                      BorderRadius.circular((_itemHeight - 4) / 2),
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
                    child: InkWell(
                      onTap: () {
                        if (s.isAction) {
                          s.onAction!();
                        } else {
                          onBranchSelected(s.branchIndex!);
                        }
                      },
                      borderRadius:
                          BorderRadius.circular(_itemHeight / 2),
                      child: AnimatedScale(
                        scale: selected ? 1.15 : 1.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          selected ? s.activeIcon : s.icon,
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          size: 24,
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
