import 'package:flutter/material.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR code on a guaranteed-scannable card.
///
/// The card is always white and the modules always dark regardless of the
/// active theme — a dark-on-dark QR cannot be read by a camera.
class QrCard extends StatelessWidget {
  const QrCard({required this.data, super.key, this.size = AppSizes.qrLarge});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appColors.qrCardBackground,
        borderRadius: BorderRadius.circular(AppRadius.qrCard),
        boxShadow: [
          BoxShadow(
            color: context.appColors.qrCardShadow,
            blurRadius: AppSizes.inputShadowBlur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: QrImageView(
        data: data,
        size: size,
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: context.appColors.qrForeground,
        ),
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: context.appColors.qrForeground,
        ),
      ),
    );
  }
}
