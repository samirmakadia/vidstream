import 'package:flutter/material.dart';

class CommonDialog {
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    String cancelText = "Cancel",
    String confirmText = "OK",
    Color confirmColor = Colors.red,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          content,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor.withOpacity(0.2),
              foregroundColor: confirmColor,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    ) ??
        false;
  }
}
