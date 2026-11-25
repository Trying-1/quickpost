import 'package:flutter/material.dart';
import 'post_template_catalog.dart';

/// Renders the visual 4:5 thumbnail preview for a [PostTemplateItem].
class PostTemplatePlaceholder extends StatelessWidget {
  final PostTemplateItem item;

  const PostTemplatePlaceholder({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.id) {
      case 'quote_card_post':
        return _buildQuoteCard();
      case 'single_image_post':
        return _buildSingleImage();
      case 'carousel_post':
        return _buildCarousel();
      case 'text_post':
        return _buildTextPost();
      case 'countdown_post':
        return _buildCountdown();
      case 'year_grid_post':
        return _buildYearGrid();
      default:
        return _buildGeneric();
    }
  }

  Widget _buildQuoteCard() {
    return Container(
      color: const Color(0xFF16161A),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [item.color, item.color.withValues(alpha: 0.5)],
                  ),
                ),
                child: const Icon(Icons.person, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 30,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.format_quote_rounded, size: 18, color: item.color.withValues(alpha: 0.8)),
            ],
          ),
          const Spacer(),
          _bar(double.infinity, 6, Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 5),
          _bar(double.infinity, 6, Colors.white.withValues(alpha: 0.85)),
          const SizedBox(height: 5),
          _bar(70, 6, item.color.withValues(alpha: 0.9)),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 12, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Icon(Icons.chat_bubble_outline, size: 12, color: Colors.white.withValues(alpha: 0.4)),
              const Spacer(),
              Icon(Icons.bookmark_border, size: 12, color: Colors.white.withValues(alpha: 0.4)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleImage() {
    return Container(
      color: const Color(0xFFF1F3F7),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [Colors.grey.shade300, Colors.grey.shade200],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Icon(Icons.image_outlined, size: 28, color: Colors.grey.shade500),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _bar(double.infinity, 5, Colors.grey.shade400),
                  const SizedBox(height: 4),
                  _bar(50, 4, item.color.withValues(alpha: 0.8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarousel() {
    return Container(
      color: const Color(0xFFFAF5EE),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.08,
            child: Container(
              width: 86,
              height: 104,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Container(
            width: 86,
            height: 104,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.view_carousel_rounded, size: 30, color: item.color),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '1 / 3',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 8,
            child: Row(
              children: [
                Container(width: 12, height: 4, decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 4),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Container(width: 4, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextPost() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.text_fields_rounded, size: 32, color: Colors.tealAccent.shade400),
            const SizedBox(height: 8),
            _bar(50, 5, Colors.white.withValues(alpha: 0.8)),
            const SizedBox(height: 4),
            _bar(32, 4, Colors.tealAccent.shade400.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E1A47), Color(0xFF1E1035)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF6C63FF), width: 3),
              ),
              child: const Center(
                child: Text(
                  '120',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'DAYS LEFT',
              style: TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearGrid() {
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 9, color: Color(0xFF2ECC71)),
              SizedBox(width: 4),
              Text(
                '365 DAYS',
                style: TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 3,
                mainAxisSpacing: 3,
              ),
              itemCount: 42,
              itemBuilder: (context, i) {
                final isFilled = (i % 3 == 0) || (i % 5 == 0);
                return Container(
                  decoration: BoxDecoration(
                    color: isFilled ? const Color(0xFF2ECC71) : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneric() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [item.color.withValues(alpha: 0.24), item.color.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(item.icon, size: 36, color: item.color),
      ),
    );
  }

  static Widget _bar(double width, double height, Color color) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

