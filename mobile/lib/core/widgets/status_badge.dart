import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase().trim();
    Color baseColor;
    String label;
    IconData? icon;

    switch (s) {
      case 'present':
      case 'hadir':
        baseColor = AppColors.hadir;
        label = 'Hadir';
        icon = Icons.check_circle_outline;
        break;
      case 'sick':
      case 'sakit':
        baseColor = AppColors.sakit;
        label = 'Sakit';
        icon = Icons.medical_services_outlined;
        break;
      case 'permission':
      case 'izin':
        baseColor = AppColors.izin;
        label = 'Izin';
        icon = Icons.assignment_outlined;
        break;
      case 'absent':
      case 'alpa':
        baseColor = AppColors.alpa;
        label = 'Alpa';
        icon = Icons.cancel_outlined;
        break;
      case 'registered':
      case 'terdaftar':
        baseColor = AppColors.primary;
        label = 'Wajah Terdaftar';
        icon = Icons.face_retouching_natural;
        break;
      default:
        baseColor = AppColors.textMuted;
        label = status;
        icon = null;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: baseColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: baseColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: baseColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
