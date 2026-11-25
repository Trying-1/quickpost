import 'dart:math' as math;

/// Builds a 4x5 color matrix combining hue rotation, saturation, and brightness gain.
List<double> buildCarouselColorMatrix(
  double brightness,
  double saturation,
  double hue,
) {
  const double lumR = 0.2126;
  const double lumG = 0.7152;
  const double lumB = 0.0722;

  final double cosH = math.cos(hue);
  final double sinH = math.sin(hue);

  final double hR1 = lumR + cosH * (1 - lumR) + sinH * (-lumR);
  final double hR2 = lumG + cosH * (-lumG) + sinH * (-lumG);
  final double hR3 = lumB + cosH * (-lumB) + sinH * (1 - lumB);

  final double hG1 = lumR + cosH * (-lumR) + sinH * 0.143;
  final double hG2 = lumG + cosH * (1 - lumG) + sinH * 0.140;
  final double hG3 = lumB + cosH * (-lumB) + sinH * (-0.283);

  final double hB1 = lumR + cosH * (-lumR) + sinH * (-(1 - lumR));
  final double hB2 = lumG + cosH * (-lumG) + sinH * lumG;
  final double hB3 = lumB + cosH * (1 - lumB) + sinH * lumB;

  final double sr1 = lumR + (1 - lumR) * saturation;
  final double sr2 = lumG - lumG * saturation;
  final double sr3 = lumB - lumB * saturation;

  final double sg1 = lumR - lumR * saturation;
  final double sg2 = lumG + (1 - lumG) * saturation;
  final double sg3 = lumB - lumB * saturation;

  final double sb1 = lumR - lumR * saturation;
  final double sb2 = lumG - lumG * saturation;
  final double sb3 = lumB + (1 - lumB) * saturation;

  final double bGain = brightness;

  return <double>[
    (hR1 * sr1 + hR2 * sg1 + hR3 * sb1) * bGain,
    (hR1 * sr2 + hR2 * sg2 + hR3 * sb2) * bGain,
    (hR1 * sr3 + hR2 * sg3 + hR3 * sb3) * bGain,
    0,
    0,
    (hG1 * sr1 + hG2 * sg1 + hG3 * sb1) * bGain,
    (hG1 * sr2 + hG2 * sg2 + hG3 * sb2) * bGain,
    (hG1 * sr3 + hG2 * sg3 + hG3 * sb3) * bGain,
    0,
    0,
    (hB1 * sr1 + hB2 * sg1 + hB3 * sb1) * bGain,
    (hB1 * sr2 + hB2 * sg2 + hB3 * sb2) * bGain,
    (hB1 * sr3 + hB2 * sg3 + hB3 * sb3) * bGain,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];
}

