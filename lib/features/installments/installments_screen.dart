import 'package:budgetti/core/l10n.dart';
import 'package:budgetti/core/providers/providers.dart';
import 'package:budgetti/features/installments/add_installment_modal.dart';
import 'package:budgetti/features/stats/widgets/section_label.dart';
import 'package:budgetti/models/installment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Installment plans: what's still running at the top, what's settled below.
/// "Active" is derived from today's date, so a plan retires itself the month
/// its last rate falls due — nothing to tick off by hand.
class InstallmentsScreen extends ConsumerWidget {
  const InstallmentsScreen({super.key});

  void _edit(BuildContext context, {Installment? existing}) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddInstallmentModal(existing: existing),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currency = ref.watch(currencyProvider);
    final plansAsync = ref.watch(installmentsProvider);
    // Real charges attached to each plan, so a row can show what the schedule
    // says *and* what the ledger confirms.
    final txns = ref.watch(installmentTransactionsProvider).value ?? const [];
    final linkedCounts = <String, int>{};
    for (final t in txns) {
      final id = t.installmentId;
      if (id != null) linkedCounts[id] = (linkedCounts[id] ?? 0) + 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.instScreenTitle,
          style: GoogleFonts.jetBrainsMono(
            color: scheme.onSurface,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context),
        child: const Icon(Icons.add),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('$err', style: TextStyle(color: scheme.error)),
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return _EmptyState(onAdd: () => _edit(context));
          }

          final active = plans.where((p) => p.isActive()).toList();
          final settled = plans.where((p) => !p.isActive()).toList();
          final owed = active.fold<double>(0, (s, p) => s + p.remainingAmount());
          final monthly =
              active.fold<double>(0, (s, p) => s + p.amountPerInstallment);

          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _Hero(
                owed: owed,
                monthly: monthly,
                activeCount: active.length,
                currency: currency,
              ),
              if (active.isNotEmpty) ...[
                SectionLabel(text: context.l10n.instActive, count: active.length),
                ...active.map((p) => _PlanRow(
                      plan: p,
                      currency: currency,
                      linkedCount: linkedCounts[p.id] ?? 0,
                      onTap: () => _edit(context, existing: p),
                      onDelete: () => ref
                          .read(financeServiceProvider)
                          .deleteInstallment(p.id),
                    )),
              ],
              if (settled.isNotEmpty) ...[
                SectionLabel(text: context.l10n.instSettled, count: settled.length),
                ...settled.map((p) => _PlanRow(
                      plan: p,
                      currency: currency,
                      linkedCount: linkedCounts[p.id] ?? 0,
                      onTap: () => _edit(context, existing: p),
                      onDelete: () => ref
                          .read(financeServiceProvider)
                          .deleteInstallment(p.id),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Total still owed across the running plans, plus what they cost per month —
/// the two numbers that actually change a spending decision.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.owed,
    required this.monthly,
    required this.activeCount,
    required this.currency,
  });

  final double owed;
  final double monthly;
  final int activeCount;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.instStillOwed,
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            currency.format(owed),
            style: GoogleFonts.bricolageGrotesque(
              color: scheme.onSurface,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.instMonthlyActive(
                currency.format(monthly), activeCount),
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.plan,
    required this.currency,
    required this.linkedCount,
    required this.onTap,
    required this.onDelete,
  });

  final Installment plan;
  final NumberFormat currency;
  final int linkedCount;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final paid = plan.paidCount();
    final next = plan.nextDueDate();
    final settled = next == null;

    return Dismissible(
      key: ValueKey(plan.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.error.withValues(alpha: 0.15),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: scheme.error),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.instDeletePlanTitle),
            content: Text(context.l10n.instDeletePlanBody(plan.description)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.commonDelete),
              ),
            ],
          ),
        );
        if (ok != true) return false;
        await onDelete();
        return true;
      },
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.description,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.bricolageGrotesque(
                        color: settled
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n
                        .instPerMo(currency.format(plan.amountPerInstallment)),
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: plan.progress(),
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(
                    settled ? scheme.onSurfaceVariant : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    context.l10n.instPaidOf(paid, plan.installmentCount),
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                  // Charges attached to the plan vs rates the schedule says are
                  // due — a shortfall means a rate is unaccounted for.
                  if (paid > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.instLinkedCount(linkedCount),
                      style: GoogleFonts.jetBrainsMono(
                        color: linkedCount >= paid
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    settled
                        ? context.l10n.instSettledLabel
                        : context.l10n.instRemainingNext(
                            currency.format(plan.remainingAmount()),
                            DateFormat.MMMd().format(next)),
                    style: GoogleFonts.jetBrainsMono(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '—',
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 72,
              fontWeight: FontWeight.w300,
              height: 0.8,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.instNoPlans,
            style: GoogleFonts.jetBrainsMono(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.instEmptyHint,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
              onPressed: onAdd, child: Text(context.l10n.instAddPlan)),
        ],
      ),
    );
  }
}
