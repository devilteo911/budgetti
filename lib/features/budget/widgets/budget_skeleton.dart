import 'package:budgetti/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';

class BudgetScreenSkeleton extends StatelessWidget {
  const BudgetScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: _HeroSkeleton()),
        const SliverToBoxAdapter(child: _SectionLabelSkeleton()),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const _RowSkeleton(),
            childCount: 6,
          ),
        ),
      ],
    );
  }
}

class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Skeleton(height: 10, width: 160, borderRadius: 2),
          SizedBox(height: 14),
          Skeleton(height: 52, width: 200, borderRadius: 4),
          SizedBox(height: 12),
          Skeleton(height: 12, width: 180, borderRadius: 2),
          SizedBox(height: 20),
          Skeleton(height: 6, width: double.infinity, borderRadius: 3),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatBlockSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _StatBlockSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _StatBlockSkeleton()),
              SizedBox(width: 12),
              Expanded(child: _StatBlockSkeleton()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlockSkeleton extends StatelessWidget {
  const _StatBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Skeleton(height: 9, width: 40, borderRadius: 2),
        SizedBox(height: 8),
        Skeleton(height: 14, width: 60, borderRadius: 2),
      ],
    );
  }
}

class _SectionLabelSkeleton extends StatelessWidget {
  const _SectionLabelSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
      child: Row(
        children: [
          const Skeleton(height: 10, width: 64, borderRadius: 2),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          const SizedBox(width: 10),
          const Skeleton(height: 10, width: 18, borderRadius: 2),
        ],
      ),
    );
  }
}

class _RowSkeleton extends StatelessWidget {
  const _RowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        children: const [
          Row(
            children: [
              Skeleton(height: 34, width: 3, borderRadius: 2),
              SizedBox(width: 14),
              Skeleton(height: 12, width: 22, borderRadius: 2),
              SizedBox(width: 8),
              Skeleton(height: 18, width: 18, borderRadius: 4),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 14, width: 120, borderRadius: 2),
                    SizedBox(height: 6),
                    Skeleton(height: 10, width: 90, borderRadius: 2),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Skeleton(height: 14, width: 60, borderRadius: 2),
                  SizedBox(height: 6),
                  Skeleton(height: 10, width: 36, borderRadius: 2),
                ],
              ),
            ],
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.only(left: 17),
            child: Skeleton(height: 3, width: double.infinity, borderRadius: 2),
          ),
        ],
      ),
    );
  }
}
