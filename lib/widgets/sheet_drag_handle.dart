import 'package:flutter/material.dart';
import 'package:meshly/theme/app_theme.dart';

/// The small grey pill shown at the top of modal bottom sheets.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key, this.bottomMargin = AppSpacing.s20});

  /// Gap between the handle and the sheet content below it.
  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.handleWidth,
        height: AppSizes.handleHeight,
        margin: EdgeInsets.only(bottom: bottomMargin),
        decoration: BoxDecoration(
          color: AppColors.dragHandle,
          borderRadius: BorderRadius.circular(AppRadius.handle),
        ),
      ),
    );
  }
}
