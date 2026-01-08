import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/subscription_plan.dart';

class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({
    super.key,
    required this.plan,
    required this.onSubscribe,
  });

  final SubscriptionPlan plan;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: plan.isPopular ? plan.accentColor : AppColors.card,
          width: 2,
        ),
        boxShadow: plan.isPopular
            ? [
                BoxShadow(
                  color: plan.accentColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Popular badge
          if (plan.isPopular)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: plan.accentColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'POPULAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

          // Main content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan subtitle (FREE PLAN, PLUS PLAN, etc.)
                Text(
                  plan.subtitle,
                  style: TextStyle(
                    color: plan.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Plan name
                Text(
                  plan.name,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Price
                if (plan.isFree)
                  Text(
                    'FREE',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.displayPrice,
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '/ month',
                          style: TextStyle(
                            color: AppColors.lightGray,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // Description
                Text(
                  plan.description,
                  style: TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 24),

                // Subscribe button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: onSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isFree
                          ? AppColors.card.withValues(alpha: 0.5)
                          : plan.accentColor,
                      foregroundColor: AppColors.white,
                      elevation: plan.isPopular ? 8 : 0,
                      shadowColor: plan.accentColor.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: plan.isFree
                            ? BorderSide(color: AppColors.lightGray, width: 1.5)
                            : BorderSide.none,
                      ),
                    ),
                    child: Text(
                      plan.isFree ? 'Current Plan' : 'Subscribe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Perks section
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.isFree
                              ? 'What\'s included:'
                              : 'Everything in ${_getPreviousPlanName()}, and:',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Perks list
                        ...plan.perks.map((perk) => _PerkItem(
                              perk: perk,
                              accentColor: plan.accentColor,
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPreviousPlanName() {
    switch (plan.type) {
      case PlanType.plus:
        return 'Starter';
      case PlanType.pro:
        return 'Plus';
      case PlanType.max:
        return 'Pro';
      default:
        return 'Previous plan';
    }
  }
}

class _PerkItem extends StatelessWidget {
  const _PerkItem({
    required this.perk,
    required this.accentColor,
  });

  final String perk;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkmark icon
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: 16,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),

          // Perk text
          Expanded(
            child: Text(
              perk,
              style: TextStyle(
                color: AppColors.lightGray,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
