import 'package:flutter/material.dart';
import '../manager/applovin_ad_manager.dart';

class NavigationHelper {
  static void navigateWithAd<T>({
    required BuildContext context,
    required Widget destination,
    void Function(T? result)? onReturn,
  }) {
    AppLovinAdManager.handleScreenOpen(() async {
      final T? result = await Navigator.of(context).push<T>(
        MaterialPageRoute(builder: (_) => destination),
      );
      if (onReturn != null) {
        onReturn(result);
      }
    });
  }
}

