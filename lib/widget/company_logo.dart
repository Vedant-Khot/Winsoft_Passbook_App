import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CompanyLogo extends StatelessWidget {
  final double size;

  const CompanyLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SvgPicture.asset(
        'assets/images/logo_small.svg',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
