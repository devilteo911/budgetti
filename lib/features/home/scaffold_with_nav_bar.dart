import 'package:budgetti/core/theme/app_theme.dart';
import 'package:budgetti/features/transactions/add_transaction_modal.dart';
import 'package:budgetti/core/services/motion_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> with WidgetsBindingObserver {
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
      backgroundColor: AppTheme.surfaceGrey,
      barrierColor: Colors.black54,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    return Scaffold(
      body: widget.navigationShell,
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 12),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryGreen.withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: 0,
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              _onAddTransaction();
            },
            backgroundColor: AppTheme.primaryGreen,
            shape: const CircleBorder(),
            elevation: 0,
            child: const Icon(
              Icons.add,
              color: AppTheme.backgroundBlack,
              size: 30,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomAppBar(
          height: 80 + MediaQuery.of(context).padding.bottom.clamp(0.0, 34.0),
          color: AppTheme.surfaceGrey,
          elevation: 0,
          padding: EdgeInsets.zero,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              8, 8, 8,
              MediaQuery.of(context).padding.bottom.clamp(8.0, 34.0),
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppTheme.surfaceGreyLight, width: 0.5),
              ),
            ),
            child: Row(
                  children: [
                    Expanded(
                      child: _buildNavItem(
                        index: 0,
                        icon: Icons.dashboard_outlined,
                        activeIcon: Icons.dashboard,
                        label: 'Dashboard',
                        isSelected: currentIndex == 0,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 1,
                        icon: Icons.receipt_long_outlined,
                        activeIcon: Icons.receipt_long,
                        label: 'History',
                        isSelected: currentIndex == 1,
                      ),
                    ),
                    const SizedBox(width: 60), // Space for FAB
                    Expanded(
                      child: _buildNavItem(
                        index: 2,
                        icon: Icons.pie_chart_outline,
                        activeIcon: Icons.pie_chart,
                        label: 'Stats',
                        isSelected: currentIndex == 2,
                      ),
                    ),
                    Expanded(
                      child: _buildNavItem(
                        index: 3,
                        icon: Icons.account_balance_wallet_outlined,
                        activeIcon: Icons.account_balance_wallet,
                        label: 'Budgets',
                        isSelected: currentIndex == 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _goBranch(index),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppTheme.primaryGreen : AppTheme.textGrey,
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? AppTheme.primaryGreen : AppTheme.textGrey,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
