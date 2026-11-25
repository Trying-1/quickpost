import 'package:flutter/material.dart';
import 'color_palette_item.dart';
import 'palette_color.dart';

/// Curated library of aesthetic, high-contrast, and trending creator color palettes.
class CuratedPalettesData {
  static List<ColorPaletteItem> getAll() {
    return [
      // ─── Trending Social & Aesthetic ───
      ColorPaletteItem(
        id: 'obsidian_neon',
        title: 'Obsidian Neon',
        category: 'Trending',
        colors: const [
          PaletteColor(color: Color(0xFF0A0A0C), name: 'Obsidian Black', role: 'Dominant'),
          PaletteColor(color: Color(0xFF1E1E2E), name: 'Deep Midnight', role: 'Dark Shade'),
          PaletteColor(color: Color(0xFF00E5FF), name: 'Electric Cyan', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF7C4DFF), name: 'Neon Purple', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFFFFFFFF), name: 'Pure White', role: 'Highlight'),
        ],
      ),
      ColorPaletteItem(
        id: 'porcelain_cobalt',
        title: 'Porcelain Cobalt',
        category: 'Trending',
        colors: const [
          PaletteColor(color: Color(0xFFF8FAFC), name: 'Porcelain White', role: 'Light Shade'),
          PaletteColor(color: Color(0xFF0F172A), name: 'Obsidian Dark', role: 'Dominant'),
          PaletteColor(color: Color(0xFF2563EB), name: 'Cobalt Azure', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF38BDF8), name: 'Sky Cyan', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFF64748B), name: 'Slate Gray', role: 'Muted Neutral'),
        ],
      ),
      ColorPaletteItem(
        id: 'nordic_minimal',
        title: 'Nordic Slate',
        category: 'Trending',
        colors: const [
          PaletteColor(color: Color(0xFF0F172A), name: 'Deep Slate', role: 'Dominant'),
          PaletteColor(color: Color(0xFF334155), name: 'Charcoal Blue', role: 'Dark Shade'),
          PaletteColor(color: Color(0xFF38BDF8), name: 'Glacier Blue', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF94A3B8), name: 'Silver Mist', role: 'Muted Neutral'),
          PaletteColor(color: Color(0xFFF1F5F9), name: 'Frost White', role: 'Highlight'),
        ],
      ),

      // ─── Cyberpunk & Neon ───
      ColorPaletteItem(
        id: 'tokyo_synthwave',
        title: 'Tokyo Synthwave',
        category: 'Cyberpunk',
        colors: const [
          PaletteColor(color: Color(0xFF120338), name: 'Void Violet', role: 'Dominant'),
          PaletteColor(color: Color(0xFFFF007F), name: 'Laser Magenta', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF00F0FF), name: 'Cyber Blue', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFFFFD600), name: 'Solar Yellow', role: 'Highlight'),
          PaletteColor(color: Color(0xFF2B096E), name: 'Neon Deep', role: 'Dark Shade'),
        ],
      ),
      ColorPaletteItem(
        id: 'matrix_hacker',
        title: 'Cyber Matrix',
        category: 'Cyberpunk',
        colors: const [
          PaletteColor(color: Color(0xFF0D1117), name: 'Terminal Black', role: 'Dominant'),
          PaletteColor(color: Color(0xFF00FF66), name: 'Phosphor Green', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF003B19), name: 'Dark Emerald', role: 'Dark Shade'),
          PaletteColor(color: Color(0xFF00B050), name: 'Matrix Pulse', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFFE6FFED), name: 'Pale Mint', role: 'Highlight'),
        ],
      ),
      ColorPaletteItem(
        id: 'electric_night',
        title: 'Electric Vice',
        category: 'Cyberpunk',
        colors: const [
          PaletteColor(color: Color(0xFF1A1A2E), name: 'Night Sky', role: 'Dominant'),
          PaletteColor(color: Color(0xFFE94560), name: 'Crimson Neon', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF0F3460), name: 'Ocean Navy', role: 'Dark Shade'),
          PaletteColor(color: Color(0xFF533483), name: 'Deep Amethyst', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFFF5F5F7), name: 'Clean White', role: 'Highlight'),
        ],
      ),

      // ─── Pastel & Soft ───
      ColorPaletteItem(
        id: 'sakura_blossom',
        title: 'Sakura Blossom',
        category: 'Pastel',
        colors: const [
          PaletteColor(color: Color(0xFFFFF0F5), name: 'Petal Cream', role: 'Light Shade'),
          PaletteColor(color: Color(0xFFFFB6C1), name: 'Cherry Blossom', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFFFF69B4), name: 'Hot Rose', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFF4A2E35), name: 'Espresso Branch', role: 'Dominant'),
          PaletteColor(color: Color(0xFFFFE4E1), name: 'Misty Rose', role: 'Muted Neutral'),
        ],
      ),
      ColorPaletteItem(
        id: 'lavender_dream',
        title: 'Lavender Cloud',
        category: 'Pastel',
        colors: const [
          PaletteColor(color: Color(0xFFF3E8FF), name: 'Lilac Mist', role: 'Light Shade'),
          PaletteColor(color: Color(0xFFC084FC), name: 'Soft Orchid', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF7E22CE), name: 'Deep Plum', role: 'Dominant'),
          PaletteColor(color: Color(0xFFE9D5FF), name: 'Pastel Violet', role: 'Muted Neutral'),
          PaletteColor(color: Color(0xFF3B0764), name: 'Midnight Violet', role: 'Dark Shade'),
        ],
      ),
      ColorPaletteItem(
        id: 'matcha_latte',
        title: 'Matcha Latte',
        category: 'Pastel',
        colors: const [
          PaletteColor(color: Color(0xFFF7FEE7), name: 'Matcha Cream', role: 'Light Shade'),
          PaletteColor(color: Color(0xFFA3E635), name: 'Bright Sprout', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF4D7C0F), name: 'Deep Olive', role: 'Dominant'),
          PaletteColor(color: Color(0xFFD9F99D), name: 'Pale Matcha', role: 'Muted Neutral'),
          PaletteColor(color: Color(0xFF1A2E05), name: 'Forest Soil', role: 'Dark Shade'),
        ],
      ),

      // ─── Warm Sunset & Golden Hour ───
      ColorPaletteItem(
        id: 'california_sunset',
        title: 'California Sunset',
        category: 'Sunset',
        colors: const [
          PaletteColor(color: Color(0xFF2B0938), name: 'Twilight Purple', role: 'Dominant'),
          PaletteColor(color: Color(0xFFFF4500), name: 'Sunset Orange', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFFFF8C00), name: 'Amber Gold', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFFFFD700), name: 'Sunbeam Yellow', role: 'Highlight'),
          PaletteColor(color: Color(0xFF6B114D), name: 'Wine Velvet', role: 'Dark Shade'),
        ],
      ),
      ColorPaletteItem(
        id: 'terracotta_dune',
        title: 'Terracotta Dune',
        category: 'Sunset',
        colors: const [
          PaletteColor(color: Color(0xFFFDFBF7), name: 'Warm Ivory', role: 'Light Shade'),
          PaletteColor(color: Color(0xFFC86D51), name: 'Terracotta Clay', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF42281D), name: 'Dark Roast', role: 'Dominant'),
          PaletteColor(color: Color(0xFFE0A96D), name: 'Desert Ochre', role: 'Secondary Accent'),
          PaletteColor(color: Color(0xFFEBE3D5), name: 'Sand Stone', role: 'Muted Neutral'),
        ],
      ),

      // ─── Luxury & Editorial ───
      ColorPaletteItem(
        id: 'champagne_noir',
        title: 'Champagne & Noir',
        category: 'Luxury',
        colors: const [
          PaletteColor(color: Color(0xFF111111), name: 'Noir Obsidian', role: 'Dominant'),
          PaletteColor(color: Color(0xFFD4AF37), name: 'Metallic Gold', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF222222), name: 'Dark Carbon', role: 'Dark Shade'),
          PaletteColor(color: Color(0xFFF4E8C1), name: 'Champagne Cream', role: 'Highlight'),
          PaletteColor(color: Color(0xFF9E8A58), name: 'Antique Bronze', role: 'Secondary Accent'),
        ],
      ),
      ColorPaletteItem(
        id: 'emerald_royale',
        title: 'Emerald Royale',
        category: 'Luxury',
        colors: const [
          PaletteColor(color: Color(0xFF042F2E), name: 'Imperial Emerald', role: 'Dominant'),
          PaletteColor(color: Color(0xFF14B8A6), name: 'Bright Jade', role: 'Vibrant Accent'),
          PaletteColor(color: Color(0xFF0F766E), name: 'Deep Teal', role: 'Dark Shade'),
          PaletteColor(color: Color(0xFFF0FDFA), name: 'Mint Silk', role: 'Highlight'),
          PaletteColor(color: Color(0xFFF59E0B), name: 'Golden Accent', role: 'Secondary Accent'),
        ],
      ),
    ];
  }
}

