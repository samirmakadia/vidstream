import 'package:flutter/material.dart';

class CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color borderColor;
  final Color iconColor;
  final int? badgeCount;
  final double size;
  final double iconSize;

  const CircularIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.borderColor = Colors.white,
    this.iconColor = Colors.white,
    this.badgeCount,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            if (badgeCount != null && badgeCount! > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
