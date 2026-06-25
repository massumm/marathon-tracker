import 'package:flutter/material.dart';

import '../core/theme.dart';

enum SpeedTier { normal, medium, fast }

SpeedTier tierFromKmh(double kmh) {
  if (kmh >= 40) return SpeedTier.fast;
  if (kmh >= 15) return SpeedTier.medium;
  return SpeedTier.normal;
}

Color colorForTier(SpeedTier tier) => switch (tier) {
      SpeedTier.normal => AppTheme.speedNormal,
      SpeedTier.medium => AppTheme.speedMedium,
      SpeedTier.fast => AppTheme.speedFast,
    };
