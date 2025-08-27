import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'graphics.dart';

class Utils{

  final BuildContext context;

  Utils(this.context);
  double get screenWidth => MediaQuery.of(context).size.width;
  double get screenHeight => MediaQuery.of(context).size.height;
  Orientation get orientation => MediaQuery.of(context).orientation;
  bool get isPortrait => orientation == Orientation.portrait;
  bool get isLandscape => orientation == Orientation.landscape;
  double widthPercentage(double percentage) => screenWidth * (percentage / 100);
  double heightPercentage(double percentage) => screenHeight * (percentage / 100);
  double get dynamicAppBarHeight {
    final paddingTop = MediaQuery.of(context).padding.top;
    return kToolbarHeight + paddingTop + 50;
  }
  ThemeData get theme => Theme.of(context);
  bool get isDark => theme.brightness == Brightness.dark;


  static bool isEmpty(String? value) {
    if(value == null) {
      return true;
    }
    return value.isEmpty;
  }

  static Size calculateBannerSize({
    required String ratio,
    required double viewportFraction,
    required double screenWidth,
  }) {
    double widthRatio = 1;
    double heightRatio = 1;

    if (ratio.contains(':')) {
      final parts = ratio.split(':');
      if (parts.length == 2) {
        final parsedWidth = double.tryParse(parts[0]);
        final parsedHeight = double.tryParse(parts[1]);

        if (parsedWidth != null && parsedHeight != null && parsedHeight != 0) {
          widthRatio = parsedWidth;
          heightRatio = parsedHeight;
        }
      }
    }

    final double aspectRatio = widthRatio / heightRatio;
    final double bannerWidth = screenWidth * viewportFraction;
    final double bannerHeight = bannerWidth / aspectRatio;

    return Size(bannerWidth, bannerHeight);
  }

  static Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? '';
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? '';
    } else {
      return '';
    }
  }

  static bool isEmptyList(List<dynamic>? value) {
    if(value == null) {
      return true;
    }
    return value.isEmpty;
  }

  static Color hexToColor(String hexColor) {
    if (hexColor.startsWith("#")) {
      hexColor = hexColor.substring(1);
    }
    if (hexColor.length == 3) {
      hexColor = hexColor.split('').map((char) => char * 2).join();
    }
    if (hexColor.length != 6 && hexColor.length != 8) {
      return Colors.white;
    }
    return Color(int.parse('0xFF$hexColor'));
  }

  static Future<void> openWebinarLink(BuildContext context, String actionData) async {
    final urlString = actionData.trim();

    if (urlString.isNotEmpty) {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url,
          mode: LaunchMode.externalApplication)) {
        Graphics.showTopDialog(context, 'Error!', 'Could not open link',type: ToastType.error);
      }
    }
  }

  static String getInitials(String name) {
    if (name.isEmpty) return '';

    final nameParts = name.trim().split(' ');
    if (nameParts.length >= 2) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    } else if (nameParts.length == 1) {
      return nameParts[0].isNotEmpty ? nameParts[0][0].toUpperCase() : '';
    }

    return '';
  }

  static bool isValidBase64(String? str) {
    if (str == null || str.isEmpty) return false;
    if (str == 'string') return false;
    if (str.length % 4 != 0) return false;
    try {
      base64Decode(str);
      return true;
    } catch (e) {
      return false;
    }
  }

  static String getDeviceType() {
    if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    } else {
      return 'unknown';
    }
  }

  static Future<String> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await deviceInfoPlugin.androidInfo;
      return "${info.brand} ${info.model} (SDK ${info.version.sdkInt})";
    } else if (Platform.isIOS) {
      final info = await deviceInfoPlugin.iosInfo;
      return "${info.utsname.machine} (iOS ${info.systemVersion})";
    } else {
      return "Unknown Device";
    }
  }

  static String generateConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}-${ids[1]}';
  }

  static String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String generateMessageId() {
    final prefix = _generateRandomString(4);
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = _generateRandomString(4);
    return '$prefix$timestamp$suffix';
  }

  static Future<DateTime?> getLastSyncDate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? dateString = prefs.getString('lastSyncedDate');

    if (dateString != null) {
      return DateTime.tryParse(dateString); // safely returns DateTime? or null
    }
    return null;
  }

  static Future<void> saveLastSyncDate() async {
    final String date = DateTime.now().toUtc().toIso8601String(); // 2025-08-26T18:30:37.830Z

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastSyncedDate', date);
  }

}


