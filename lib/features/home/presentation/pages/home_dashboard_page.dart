import 'package:flutter/material.dart';

import 'package:smart_tutor_lite/app/routes.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE0F2F1), // Light blue-green
            const Color(0xFFFFF7E9), // Cream/white
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildSearchBar(context),
              const SizedBox(height: 24),
              _buildFeatureGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, Learner!',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'How can I assist you today?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                "Let's Learn Something",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.black87,
                    ),
              ),
              Text(
                'Awesome!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      color: Colors.black87,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.tertiary.withValues(alpha: 0.2),
          child: Icon(
            Icons.person,
            color: colorScheme.tertiary,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search new courses...',
                hintStyle: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.mic_rounded,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 0.9,
      children: [
        _HomeFeatureCard(
          title: 'Smart record',
          subtitle: 'Lectures->notes',
          icon: Icons.mic_none_outlined,
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.transcription);
          },
        ),
        _HomeFeatureCard(
          title: 'Summary Bot',
          subtitle: 'Summarize notes',
          icon: Icons.description_outlined,
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.summarization);
          },
        ),
        _HomeFeatureCard(
          title: 'Practice mode',
          subtitle: 'Quizzes & drills',
          icon: Icons.lightbulb_outline,
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.quiz);
          },
        ),
        _HomeFeatureCard(
          title: 'Audio Notes',
          subtitle: 'Listen on the go',
          icon: Icons.graphic_eq_outlined,
          onTap: () {
            Navigator.pushNamed(context, AppRoutes.tts);
          },
        ),
      ],
    );
  }
}

class _HomeFeatureCard extends StatelessWidget {
  const _HomeFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFDFF4F9), // matches screenshot
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color.fromARGB(255, 110, 106, 106).withValues(
              alpha: 0.6,
            ),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                icon,
                color: Colors.black.withValues(alpha: 0.65),
                size: 22,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
