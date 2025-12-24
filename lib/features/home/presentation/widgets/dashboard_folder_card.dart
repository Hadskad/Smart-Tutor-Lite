import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A reusable card widget for displaying study folders in the dashboard grid.
/// 
/// This widget matches the design style of _FeatureCard used in the home dashboard.
class DashboardFolderCard extends StatelessWidget {
  const DashboardFolderCard({
    super.key,
    required this.title,
    required this.onTap,
    this.isCreateTile = false,
    this.materialCount = 0,
  });

  final String title;
  final VoidCallback onTap;
  final bool isCreateTile;
  final int materialCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Stack(
          children: [
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (isCreateTile)
                    const Icon(
                      Icons.add_circle_outline,
                      size: 38,
                      color: AppColors.accentBlue,
                    )
                  else
                    const Icon(
                      Icons.folder_outlined,
                      size: 38,
                      color: AppColors.accentBlue,
                    ),
                  const SizedBox(height: 5),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isCreateTile ? AppColors.lightGray : AppColors.white,
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
            // Material count badge (only for non-create tiles with materials)
            if (!isCreateTile && materialCount > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    materialCount > 99 ? '99+' : materialCount.toString(),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
