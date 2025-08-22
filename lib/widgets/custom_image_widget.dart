import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';


class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonLoader({required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.black12,
      highlightColor: Colors.white10,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class CustomImageWidget extends StatelessWidget {
  final String imageUrl;
  final double cornerRadius;
  final double topLeftRadius;
  final double topRightRadius;
  final double bottomLeftRadius;
  final double bottomRightRadius;
  final double height;
  final double width;
  final BoxFit fit;
  final Color borderColor;
  final double borderWidth;
  final bool? isSquare;
  final bool isUserInitial;
  final String? initials;
  final Color? initialsBgColor;
  final TextStyle? initialsTextStyle;
  final bool isSetColor;

  const CustomImageWidget({
    required this.imageUrl,
    this.cornerRadius = 0,
    this.topLeftRadius = -1,
    this.topRightRadius = -1,
    this.bottomLeftRadius = -1,
    this.bottomRightRadius = -1,
    required this.height,
    required this.width,
    this.fit = BoxFit.cover,
    this.borderWidth = 1,
    this.isSquare = false,
    this.borderColor = Colors.transparent,
    this.isUserInitial = false,
    this.initials,
    this.initialsBgColor,
    this.initialsTextStyle, this.isSetColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final topLeft = topLeftRadius == -1 ? cornerRadius : topLeftRadius;
    final topRight = topRightRadius == -1 ? cornerRadius : topRightRadius;
    final bottomLeft = bottomLeftRadius == -1 ? cornerRadius : bottomLeftRadius;
    final bottomRight = bottomRightRadius == -1 ? cornerRadius : bottomRightRadius;

    final bool showInitial = isUserInitial && (imageUrl.isEmpty || imageUrl.trim().isEmpty);

    if (showInitial) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: initialsBgColor ?? Colors.grey.shade300,
        ),
        alignment: Alignment.center,
        child: Text(
          initials ?? '',
          style: initialsTextStyle ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeft),
          topRight: Radius.circular(topRight),
          bottomLeft: Radius.circular(bottomLeft),
          bottomRight: Radius.circular(bottomRight),
        ),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(topLeft),
          topRight: Radius.circular(topRight),
          bottomLeft: Radius.circular(bottomLeft),
          bottomRight: Radius.circular(bottomRight),
        ),
        child: imageUrl.isNotEmpty
            ? imageUrl.contains("http")
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fadeInDuration: const Duration(milliseconds: 100),
                    fadeOutDuration: const Duration(milliseconds: 100),
                    placeholder: (context, url) => SkeletonLoader(
                      width: width,
                      height: height,
                      radius: cornerRadius,
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(cornerRadius),
                      ),
                      child: Icon(Icons.image, color: Colors.grey[400], size: width * 0.3),
                    ),
                    fit: fit,
                    height: height,
                    width: width,
                  )
                : File(imageUrl).existsSync()
                    ? Image.file(File(imageUrl), fit: fit, height: height, width: width)
                    : Container(
                        width: width,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(cornerRadius),
                        ),
                        child: Icon(Icons.image, color: Colors.grey[400], size: width * 0.3),
                      )
            : Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(cornerRadius),
                ),
                child: Icon(Icons.image, color: Colors.grey[400], size: width * 0.3),
              ),
      ),
    );
  }
}
