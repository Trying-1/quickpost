import 'dart:typed_data';

/// Represents a single sliced tile from the grid split operation.
class GridPostTile {
  final int tileIndex; // 0-based index (reading order: left-to-right, top-to-bottom)
  final int row;
  final int col;
  final int postingOrder; // 1-based order to upload to Instagram (1 = first to upload)
  final int totalTiles;
  final Uint8List imageBytes;
  final String? savedPath;

  const GridPostTile({
    required this.tileIndex,
    required this.row,
    required this.col,
    required this.postingOrder,
    required this.totalTiles,
    required this.imageBytes,
    this.savedPath,
  });

  String get positionLabel => 'Tile ${tileIndex + 1} of $totalTiles';
  String get postingOrderLabel => 'Post #$postingOrder';
}
