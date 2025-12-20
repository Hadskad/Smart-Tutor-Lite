import 'package:flutter/material.dart';

// Reuse colors from home_dashboard_page.dart
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);

/// A reusable card widget for displaying study folders in the dashboard grid.
/// 
/// This widget matches the design style of _FeatureCard used in the home dashboard.
class DashboardFolderCard extends StatelessWidget {
  const DashboardFolderCard({
    super.key,
    required this.title,
    required this.onTap,
    this.isCreateTile = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool isCreateTile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isCreateTile)
              Icon(
                Icons.add_circle_outline,
                size: 38,
                color: _kAccentBlue,
              )
            else
              Icon(
                Icons.folder_outlined,
                size: 38,
                color: _kAccentBlue,
              ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(
                title,
                style: TextStyle(
                  color: isCreateTile ? _kLightGray : _kWhite,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

