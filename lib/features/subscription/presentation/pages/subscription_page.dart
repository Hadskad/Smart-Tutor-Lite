import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/subscription_plan_card.dart';
import '../models/subscription_plan.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Choose Your Plan',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 5),
          
           

            // Horizontal Scrollable Plans
            Expanded(
              child: PageView.builder(
                controller: PageController(
                  viewportFraction: 0.88,
                  initialPage: 0,
                ),
                itemCount: SubscriptionPlan.allPlans.length,
                itemBuilder: (context, index) {
                  final plan = SubscriptionPlan.allPlans[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: SubscriptionPlanCard(
                      plan: plan,
                      onSubscribe: () {
                        // TODO: Handle subscription logic
                        _handleSubscription(context, plan);
                      },
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Plan indicators
            _PlanIndicators(totalPlans: SubscriptionPlan.allPlans.length),

            const SizedBox(height: 20),

           
          ],
        ),
      ),
    );
  }

  void _handleSubscription(BuildContext context, SubscriptionPlan plan) {
    // TODO: Implement subscription logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${plan.name} plan selected - Payment integration pending'),
        backgroundColor: AppColors.accentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _PlanIndicators extends StatelessWidget {
  const _PlanIndicators({required this.totalPlans});

  final int totalPlans;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalPlans,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.lightGray.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}
