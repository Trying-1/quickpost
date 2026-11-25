import 'package:flutter/material.dart';
import 'package:quickpost/config/app_theme.dart';
import 'package:quickpost/screens/anime_post/models/anime_db_entry.dart';

/// Offline Database Analytics dialog showing verified coverage,
/// studio distribution, genre breakdown, and tagged artwork coverage.
class AnimeDbStatsDialog extends StatelessWidget {
  final List<AnimeDbEntry> entries;

  const AnimeDbStatsDialog({super.key, required this.entries});

  static Future<void> show(BuildContext context, {required List<AnimeDbEntry> entries}) {
    return showDialog(
      context: context,
      builder: (_) => AnimeDbStatsDialog(entries: entries),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = entries.length;
    final verifiedCount = entries.where((e) => e.verified).length;
    final verifiedPct = total > 0 ? (verifiedCount / total * 100).toStringAsFixed(0) : '0';

    // Studios breakdown
    final studioMap = <String, int>{};
    for (final e in entries) {
      final s = e.studio.trim();
      if (s.isNotEmpty) {
        studioMap[s] = (studioMap[s] ?? 0) + 1;
      }
    }
    final sortedStudios = studioMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Genres breakdown
    final genreMap = <String, int>{};
    for (final e in entries) {
      if (e.genres.trim().isEmpty) continue;
      final parts = e.genres.split(RegExp(r'[,/•|]'));
      for (var p in parts) {
        p = p.trim();
        if (p.isNotEmpty) {
          genreMap[p] = (genreMap[p] ?? 0) + 1;
        }
      }
    }
    final sortedGenres = genreMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Decades
    int decade2020s = 0, decade2010s = 0, decadeClassic = 0;
    for (final e in entries) {
      if (e.year == null) continue;
      if (e.year! >= 2020) {
        decade2020s++;
      } else if (e.year! >= 2010) {
        decade2010s++;
      } else {
        decadeClassic++;
      }
    }

    final maxHeight = (MediaQuery.of(context).size.height * 0.85).clamp(360.0, 620.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Database Analytics',
                          style: TextStyle(
                            fontFamily: AppTextStyles.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Offline local statistics & coverage',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Scrollable Stats Body
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Overview Metric Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Total Anime',
                            value: '$total',
                            icon: Icons.movie_filter_rounded,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricCard(
                            label: 'Verified ($verifiedPct%)',
                            value: '$verifiedCount / $total',
                            icon: Icons.verified_rounded,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Era / Decade Distribution
                    const Text(
                      'ERA DISTRIBUTION',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildEraBadge('2020s Hits', decade2020s, const Color(0xFF0EA5E9)),
                        const SizedBox(width: 8),
                        _buildEraBadge('2010s Golden', decade2010s, const Color(0xFF8B5CF6)),
                        const SizedBox(width: 8),
                        _buildEraBadge('Classics & 90s', decadeClassic, const Color(0xFFF59E0B)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Top Studios
                    if (sortedStudios.isNotEmpty) ...[
                      const Text(
                        'TOP STUDIOS IN DATABASE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...sortedStudios.take(5).map((entry) {
                        final pct = total > 0 ? entry.value / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.key,
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${entry.value} anime',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFF6366F1)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],

                    // Top Genres
                    if (sortedGenres.isNotEmpty) ...[
                      const Text(
                        'TOP GENRES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sortedGenres.take(12).map((g) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  g.key,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${g.value}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6366F1)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Zero-API Offline Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.offline_bolt_rounded, size: 20, color: Color(0xFF16A34A)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '100% Offline & Private: No external APIs or rate limits. Data is stored on your device and synced with Anime Post Maker.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF15803D), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildEraBadge(String name, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

