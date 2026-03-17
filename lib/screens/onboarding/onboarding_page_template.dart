import 'package:flutter/material.dart';

class OnboardingPageTemplate extends StatelessWidget {
  final List<Color> gradient;
  final IconData heroIcon;
  final String title;
  final String description;
  final List<String> bullets;

  const OnboardingPageTemplate({
    super.key,
    required this.gradient,
    required this.heroIcon,
    required this.title,
    required this.description,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = const Color(0xFFF4F5F7);
    final card = const Color(0xFFF7F8FA);
    final titleColor = const Color(0xFF0F172A);
    final bodyColor = const Color(0xFF334155);
    final accent = scheme.primary;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF4F5F7),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              _HeroIcon(icon: heroIcon),
              const SizedBox(height: 22),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 32,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  fontFamily: 'Metrophobic',
                  fontSize: 15,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.1,
                  color: bodyColor,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.9),
                      blurRadius: 18,
                      offset: const Offset(-8, -8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 18,
                      offset: const Offset(10, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...bullets.map(
                      (b) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              margin: const EdgeInsets.only(top: 1),
                              decoration: BoxDecoration(
                                color: bg,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.95),
                                    blurRadius: 10,
                                    offset: const Offset(-4, -4),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 10,
                                    offset: const Offset(4, 4),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.check, size: 14, color: accent),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                b,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.5,
                                  height: 1.35,
                                  color: titleColor,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;

  const _HeroIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = const Color(0xFFF4F5F7);

    return SizedBox(
      height: 120,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Positioned(
            left: 36,
            top: 10,
            child: _GlowBlob(
              size: 90,
              color: scheme.primary.withOpacity(0.10),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 8,
            child: _GlowBlob(
              size: 74,
              color: scheme.primary.withOpacity(0.12),
            ),
          ),
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: bg,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.95),
                  blurRadius: 18,
                  offset: const Offset(-10, -10),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(12, 12),
                ),
              ],
            ),
            child: Icon(icon, size: 46, color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowBlob({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
