import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

import '../utils/graphics.dart';

class AppUpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final bool hasUpdate;
  final bool isForceUpdate;
  final String? releaseNotes;
  final String downloadUrl;

  AppUpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.hasUpdate,
    required this.isForceUpdate,
    this.releaseNotes,
    required this.downloadUrl,
  });
}

class AppUpdateDialog extends StatefulWidget {
  final AppUpdateInfo updateInfo;
  
  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
  });

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();

  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: !updateInfo.isForceUpdate,
      builder: (BuildContext context) => AppUpdateDialog(updateInfo: updateInfo),
    );
  }

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      // Get latest version from store (you would implement this with your backend)
      final updateInfo = await _getUpdateInfoFromStore(packageInfo.packageName, currentVersion);
      
      return updateInfo;
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return null;
    }
  }

  static Future<AppUpdateInfo?> _getUpdateInfoFromStore(String packageName, String currentVersion) async {
    try {
      String latestVersion = currentVersion;
      String downloadUrl = '';
      String? releaseNotes;
      
      if (Platform.isAndroid) {
        // Check Google Play Store
        final response = await http.get(
          Uri.parse('https://play.google.com/store/apps/details?id=$packageName&hl=en'),
        );
        
        if (response.statusCode == 200) {
          // Parse HTML to get version (simplified - in production use Play Store API)
          final String responseBody = response.body;
          final RegExp versionRegex = RegExp(r'Current Version</div><span[^>]*>([^<]+)</span>');
          final Match? versionMatch = versionRegex.firstMatch(responseBody);
          
          if (versionMatch != null) {
            latestVersion = versionMatch.group(1)?.trim() ?? currentVersion;
          }
          
          downloadUrl = 'https://play.google.com/store/apps/details?id=$packageName';
        }
      } else if (Platform.isIOS) {
        // Check App Store (you would use iTunes Search API)
        final response = await http.get(
          Uri.parse('https://itunes.apple.com/lookup?bundleId=$packageName'),
        );
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List results = data['results'] ?? [];
          
          if (results.isNotEmpty) {
            final appData = results[0];
            latestVersion = appData['version'] ?? currentVersion;
            releaseNotes = appData['releaseNotes'];
            downloadUrl = appData['trackViewUrl'] ?? '';
          }
        }
      }
      
      // Compare versions
      final hasUpdate = _compareVersions(currentVersion, latestVersion) < 0;
      final isForceUpdate = _isForceUpdate(currentVersion, latestVersion);
      
      return AppUpdateInfo(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        hasUpdate: hasUpdate,
        isForceUpdate: isForceUpdate,
        releaseNotes: releaseNotes,
        downloadUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('Error getting update info from store: $e');
      return null;
    }
  }

  static int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();
    
    final maxLength = v1Parts.length > v2Parts.length ? v1Parts.length : v2Parts.length;
    
    for (int i = 0; i < maxLength; i++) {
      final v1Part = i < v1Parts.length ? v1Parts[i] : 0;
      final v2Part = i < v2Parts.length ? v2Parts[i] : 0;
      
      if (v1Part < v2Part) return -1;
      if (v1Part > v2Part) return 1;
    }
    
    return 0;
  }

  static bool _isForceUpdate(String currentVersion, String latestVersion) {
    // Implement your force update logic here
    // For example, force update if major version difference is > 1
    final currentMajor = int.tryParse(currentVersion.split('.').first) ?? 0;
    final latestMajor = int.tryParse(latestVersion.split('.').first) ?? 0;
    
    return (latestMajor - currentMajor) > 1;
  }
}

class _AppUpdateDialogState extends State<AppUpdateDialog> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _scaleController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _updateApp() async {
    setState(() {
      _updating = true;
    });

    try {
      final Uri url = Uri.parse(widget.updateInfo.downloadUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error opening update URL: $e');
      if (mounted) {
        Graphics.showTopDialog(
          context,
          "Error!",
          'Failed to open app store',
          type: ToastType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final updateInfo = widget.updateInfo;
    
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 10,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Update Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: updateInfo.isForceUpdate
                          ? [Colors.red, Colors.red.withValues(alpha: 0.7)]
                          : [Colors.blue, Colors.blue.withValues(alpha: 0.7)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (updateInfo.isForceUpdate ? Colors.red : Colors.blue)
                            .withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Icon(
                    updateInfo.isForceUpdate ? Icons.system_update_alt : Icons.update,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  updateInfo.isForceUpdate ? 'Update Required' : 'Update Available',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Version Info
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    children: [
                      const TextSpan(text: 'Version '),
                      TextSpan(
                        text: updateInfo.latestVersion,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      const TextSpan(text: ' is now available.\nYou have version '),
                      TextSpan(
                        text: updateInfo.currentVersion,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Release Notes
                if (updateInfo.releaseNotes != null && updateInfo.releaseNotes!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What\'s New:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          updateInfo.releaseNotes!,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Warning for force update
                if (updateInfo.isForceUpdate) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This update is required to continue using the app.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Action Buttons
                Row(
                  children: [
                    if (!updateInfo.isForceUpdate) ...[
                      Expanded(
                        child: TextButton(
                          onPressed: _updating ? null : () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: updateInfo.isForceUpdate ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: _updating ? null : _updateApp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: updateInfo.isForceUpdate ? Colors.red : theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          elevation: 5,
                        ),
                        child: _updating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                updateInfo.isForceUpdate ? 'Update Now' : 'Update',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}