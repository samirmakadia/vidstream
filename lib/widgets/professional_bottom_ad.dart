import 'package:flutter/material.dart';
import 'banner_ad_with_loader.dart';

class ProfessionalBottomAd extends StatefulWidget {
  final Widget child;

  const ProfessionalBottomAd({
    super.key,
    required this.child,
  });

  @override
  State<ProfessionalBottomAd> createState() => _ProfessionalBottomAdState();
}

class _ProfessionalBottomAdState extends State<ProfessionalBottomAd> {

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        BannerAdWithLoader(key: UniqueKey(),),
      ],
    );
  }
}
