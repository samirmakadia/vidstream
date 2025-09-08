import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';

enum ToastType { success, error, warning }

class Graphics{

  final BuildContext context;

  Graphics(this.context);

  static void showTopDialog(BuildContext context, String? title, String subtitle, {ToastType type = ToastType.success, String? actionLabel, VoidCallback? onAction,}) {
    Color backgroundColor;
    Widget icon;

    switch (type) {
      case ToastType.error:
        backgroundColor = Colors.red.shade400;
        icon = const Icon(Icons.error, color: Colors.white, size: 30);
        break;
      case ToastType.warning:
        backgroundColor = Colors.orange.shade400;
        icon = const Icon(Icons.warning, color: Colors.white, size: 30);
        break;
      case ToastType.success:
      default:
        backgroundColor = Colors.green.shade400;
        icon = const Icon(Icons.check_circle, color: Colors.white, size: 30);
        break;
    }

    Duration duration = const Duration(seconds: 2);

    showGeneralDialog(
      barrierLabel: "Popup",
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 700),
      context: context,
      pageBuilder: (context, anim1, anim2) {
        Future.delayed(duration, () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return Align(
          alignment: Alignment.topCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 50, left: 20, right: 20),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 15),
                    child: icon,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title ?? '7NIGHTS',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: Colors.white)),
                        Text(subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white)),
                        if (actionLabel != null && onAction != null)
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(); // close dialog
                              onAction();
                            },
                            child: Text(
                              actionLabel,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.elasticOut,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }



  static void showToast({
    required String message,
    bool isSuccess = true,
    ToastGravity gravity = ToastGravity.TOP,
    double fontSize = 16.0,
  }) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: gravity,
      backgroundColor: isSuccess ? Colors.green : Colors.red,
      textColor: Colors.white,
      fontSize: fontSize,
    );
  }

}


