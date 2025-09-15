import 'dart:async';
import 'package:flutter/material.dart';

class LoadingAdsText extends StatefulWidget {
  const LoadingAdsText({super.key});

  @override
  State<LoadingAdsText> createState() => _LoadingAdsTextState();
}

class _LoadingAdsTextState extends State<LoadingAdsText> {
  int _dotCount = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    final spaces = ' ' * (3 - _dotCount);
    return Text(
      'Loading Ads$dots$spaces',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
