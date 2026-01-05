import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/core/services/motion_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  int _previousIndex = 0;
  late MotionService _motionService;

  @override
  void initState() {
    super.initState();
    _motionService = MotionService(onTwistDetected: _onTwistDetected);
    _motionService.startListening();
  }

  @override
  void dispose() {
    _motionService.stopListening();
    super.dispose();
  }

  void _onTwistDetected() {
    // Only trigger if a modal is not already showing (optional but safer)
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceGrey,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const AddTransactionModal(triggerScan: true),
    );
  }

  @override
  void didUpdateWidget(ScaffoldWithNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex != widget.navigationShell.currentIndex) {
      _previousIndex = oldWidget.navigationShell.currentIndex;
    }
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
    final isForward = currentIndex >= _previousIndex;

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final bool isIncoming = child.key == ValueKey(currentIndex);
          
          Offset begin;
          if (isIncoming) {
            begin = isForward ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0);
          } else {
            begin = isForward ? const Offset(-1.0, 0.0) : const Offset(1.0, 0.0);
          }

          return SlideTransition(
            position: animation.drive(Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            children: <Widget>[
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: KeyedSubtree(
          key: ValueKey(currentIndex),
          child: widget.navigationShell,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _goBranch,
        backgroundColor: AppTheme.backgroundBlack,
        indicatorColor: AppTheme.primaryGreen.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Stats',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Budgets',
          ),
        ],
      ),
    );
  }
}
