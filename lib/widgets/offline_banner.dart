import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/offline_storage_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Obx(() {
      final isOnline = OfflineStorageService.instance.isOnline.value;
      return IgnorePointer(
        child: Padding(
          padding: EdgeInsets.only(top: topPad + 10, right: 14),
          child: Align(
            alignment: Alignment.topRight,
            child: AnimatedSlide(
              offset: isOnline ? const Offset(2.0, 0) : Offset.zero,
              duration: const Duration(milliseconds: 420),
              curve: isOnline ? Curves.easeIn : Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded,
                        size: 13, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'No internet',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}
