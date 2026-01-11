import 'package:flutter/material.dart';
import '../../design_system/colors.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'أرباحي',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: HadhirColors.secondary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'قريباً: شاشة الأرباح',
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
