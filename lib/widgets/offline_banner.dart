import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/offline_storage_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _showBanner = false;
  Timer? _debounce;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _worker = ever(OfflineStorageService.instance.isOnline, _onConnectivityChange);
  }

  void _onConnectivityChange(bool? isOnline) {
    _debounce?.cancel();
    if (isOnline == false) {
      // Only show after 1.5 s of confirmed offline to avoid startup flicker.
      _debounce = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _showBanner = true);
      });
    } else {
      if (mounted) setState(() => _showBanner = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _worker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return IgnorePointer(
      child: Padding(
        padding: EdgeInsets.only(top: topPad + 10, right: 14),
        child: Align(
          alignment: Alignment.topRight,
          child: AnimatedSlide(
            offset: _showBanner ? Offset.zero : const Offset(2.0, 0),
            duration: const Duration(milliseconds: 420),
            curve: _showBanner ? Curves.easeOut : Curves.easeIn,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                  Icon(Icons.wifi_off_rounded, size: 13, color: Colors.white),
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
  }
}
