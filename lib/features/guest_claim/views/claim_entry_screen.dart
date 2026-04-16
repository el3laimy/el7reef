import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/claim_entry_controller.dart';

class ClaimEntryScreen extends GetView<ClaimEntryController> {
  const ClaimEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Obx(() {
            final errorMessage = controller.errorMessage.value;
            if (errorMessage.isNotEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.link_off_rounded,
                      size: 52,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذر فتح رابط الـ claim',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            return const Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'جارٍ تجهيز رابط الاستلام...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}
