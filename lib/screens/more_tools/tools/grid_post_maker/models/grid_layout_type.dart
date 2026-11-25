/// Supported grid layout presets for Instagram profile splits.
enum GridLayoutType {
  banner3x1(
    id: 'banner3x1',
    label: '3 × 1 Banner',
    subtitle: '3 Posts in 1 Row',
    cols: 3,
    rows: 1,
    aspectRatio: 3.0 / 1.0,
    badge: 'Trending',
  ),
  grid3x2(
    id: 'grid3x2',
    label: '3 × 2 Grid',
    subtitle: '6 Posts in 2 Rows',
    cols: 3,
    rows: 2,
    aspectRatio: 3.0 / 2.0,
    badge: 'Popular',
  ),
  square3x3(
    id: 'square3x3',
    label: '3 × 3 Giant Grid',
    subtitle: '9 Posts Square Puzzle',
    cols: 3,
    rows: 3,
    aspectRatio: 3.0 / 3.0,
    badge: 'Classic',
  ),
  grid3x4(
    id: 'grid3x4',
    label: '3 × 4 Master',
    subtitle: '12 Posts in 4 Rows',
    cols: 3,
    rows: 4,
    aspectRatio: 3.0 / 4.0,
    badge: 'Giant',
  ),
  vertical1x3(
    id: 'vertical1x3',
    label: '1 × 3 Vertical',
    subtitle: '3 Posts Single Column',
    cols: 1,
    rows: 3,
    aspectRatio: 1.0 / 3.0,
    badge: 'Column',
  );

  final String id;
  final String label;
  final String subtitle;
  final int cols;
  final int rows;
  final double aspectRatio;
  final String badge;

  const GridLayoutType({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.cols,
    required this.rows,
    required this.aspectRatio,
    required this.badge,
  });

  int get totalTiles => cols * rows;

  /// Calculates the posting order for a tile at [tileIndex] (0-based, top-left to bottom-right).
  /// To reconstruct correctly on an Instagram profile, posts must be uploaded in reverse
  /// (from bottom-right to top-left).
  int getPostingOrder(int tileIndex) {
    return totalTiles - tileIndex;
  }
}

