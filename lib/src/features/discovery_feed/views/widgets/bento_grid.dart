import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/widgets/skeleton/skeletons.dart';
import '../../controllers/discovery_feed_controller.dart';
import 'discover_tile.dart';

/// A tile's cell placement within a [BentoBlock]'s 2 × 2 grid of square cells.
class BentoCell {
  const BentoCell(this.column, this.row, this.columnSpan, this.rowSpan);

  final int column;
  final int row;
  final int columnSpan;
  final int rowSpan;

  DiscoverTileSize get tileSize =>
      columnSpan * rowSpan >= 4 ? DiscoverTileSize.hero : DiscoverTileSize.regular;
}

/// Grid size of every block.
const int bentoColumns = 2;
const int bentoRows = 2;

/// One full-width band of the bento grid: 2 columns × 2 rows of square
/// cells holding the posts from [start], one per cell in [cells] order.
class BentoBlock {
  const BentoBlock({required this.start, required this.cells});

  final int start;
  final List<BentoCell> cells;

  int get length => cells.length;
}

/// The repeating patterns, in reading order (each fills every cell):
///
///     A B    A B    A A
///     A C    C B    A A
const List<List<BentoCell>> _patterns = [
  [BentoCell(0, 0, 1, 2), BentoCell(1, 0, 1, 1), BentoCell(1, 1, 1, 1)],
  [BentoCell(0, 0, 1, 1), BentoCell(1, 0, 1, 2), BentoCell(0, 1, 1, 1)],
  [BentoCell(0, 0, 2, 2)],
];

/// Closing block for the last two posts of a finished feed.
const List<BentoCell> _pair = [BentoCell(0, 0, 1, 2), BentoCell(1, 0, 1, 2)];

/// Splits [count] posts into bento blocks.
///
/// Block `i` always uses the same pattern, so loading another page only
/// appends blocks and never reshuffles what's on screen. Posts that don't
/// fill a whole pattern are held back while [complete] is false (the next
/// page will complete the block), and laid out in a closing block once it's
/// true.
List<BentoBlock> bentoBlocks(int count, {required bool complete}) {
  final blocks = <BentoBlock>[];
  var start = 0;
  while (true) {
    final pattern = _patterns[blocks.length % _patterns.length];
    if (count - start < pattern.length) break;
    blocks.add(BentoBlock(start: start, cells: pattern));
    start += pattern.length;
  }
  final remaining = count - start;
  if (complete && remaining > 0) {
    // Only 1 or 2 can remain: the next pattern needs 3.
    blocks.add(BentoBlock(start: start, cells: remaining == 1 ? _patterns.last : _pair));
  }
  return blocks;
}

/// Geometry shared by the bento grid and its skeleton.
abstract final class BentoMetrics {
  static const double gap = 10;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 4, 16, 0);

  /// Widest the grid gets; wider screens centre it so cells don't balloon.
  static const double maxWidth = 720;

  static double cellSize(double width) => (width - gap * (bentoColumns - 1)) / bentoColumns;
  static double blockHeight(double width) => cellSize(width) * bentoRows + gap * (bentoRows - 1);
}

/// Lays [entries] out as an editorial "bento" grid of mixed tile sizes.
class SliverBentoGrid extends StatelessWidget {
  const SliverBentoGrid({super.key, required this.entries, required this.complete});

  final List<FeedEntry> entries;

  /// Whether the feed has no more pages (see [bentoBlocks]).
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final blocks = bentoBlocks(entries.length, complete: complete);
    return SliverPadding(
      padding: BentoMetrics.padding,
      sliver: SliverList.separated(
        itemCount: blocks.length,
        separatorBuilder: (_, _) => const SizedBox(height: BentoMetrics.gap),
        itemBuilder: (context, index) {
          final block = blocks[index];
          return _BentoBlockView(
            cells: block.cells,
            childFor: (i, cell) => DiscoverTile(entry: entries[block.start + i], size: cell.tileSize),
          );
        },
      ),
    );
  }
}

/// Shimmering placeholder in the shape of the first two bento blocks.
class SliverBentoSkeleton extends StatelessWidget {
  const SliverBentoSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: BentoMetrics.padding,
      sliver: SliverList.separated(
        itemCount: 2,
        separatorBuilder: (_, _) => const SizedBox(height: BentoMetrics.gap),
        itemBuilder: (_, index) => Shimmer(
          child: _BentoBlockView(
            cells: _patterns[index],
            childFor: (_, _) => const SkeletonBox(borderRadius: discoverTileRadius),
          ),
        ),
      ),
    );
  }
}

class _BentoBlockView extends StatelessWidget {
  const _BentoBlockView({required this.cells, required this.childFor});

  final List<BentoCell> cells;
  final Widget Function(int index, BentoCell cell) childFor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: BentoMetrics.maxWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, BentoMetrics.maxWidth);
            final cell = BentoMetrics.cellSize(width);
            double extent(int span) => cell * span + BentoMetrics.gap * (span - 1);
            return SizedBox(
              height: BentoMetrics.blockHeight(width),
              child: Stack(
                children: [
                  for (var i = 0; i < cells.length; i++)
                    Positioned(
                      left: cells[i].column * (cell + BentoMetrics.gap),
                      top: cells[i].row * (cell + BentoMetrics.gap),
                      width: extent(cells[i].columnSpan),
                      height: extent(cells[i].rowSpan),
                      child: childFor(i, cells[i]),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
