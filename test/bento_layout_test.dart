import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/features/discovery_feed/views/widgets/bento_grid.dart';

/// Every cell of a block covered exactly once.
void _expectFills(BentoBlock block) {
  final covered = <(int, int)>[];
  for (final cell in block.cells) {
    for (var c = cell.column; c < cell.column + cell.columnSpan; c++) {
      for (var r = cell.row; r < cell.row + cell.rowSpan; r++) {
        covered.add((c, r));
      }
    }
  }
  const cells = bentoColumns * bentoRows;
  expect(covered.length, cells, reason: 'block at ${block.start} must cover every cell');
  expect(covered.toSet().length, cells, reason: 'block at ${block.start} has overlapping tiles');
  expect(covered.every((p) => p.$1 >= 0 && p.$1 < bentoColumns && p.$2 >= 0 && p.$2 < bentoRows), isTrue);
}

void main() {
  test('every block fills its grid without overlaps', () {
    for (var count = 1; count <= 40; count++) {
      for (final complete in [true, false]) {
        bentoBlocks(count, complete: complete).forEach(_expectFills);
      }
    }
  });

  test('a finished feed places every post exactly once, in order', () {
    for (var count = 0; count <= 40; count++) {
      final blocks = bentoBlocks(count, complete: true);
      var next = 0;
      for (final block in blocks) {
        expect(block.start, next);
        next += block.length;
      }
      expect(next, count);
    }
  });

  test('while more pages are coming, partial blocks are held back', () {
    // Patterns hold 3, 3, 1 posts: 5 posts fill only the first block.
    final blocks = bentoBlocks(5, complete: false);
    expect(blocks, hasLength(1));
    expect(blocks.single.length, 3);
  });

  test('loading another page only appends blocks', () {
    final before = bentoBlocks(18, complete: false);
    final after = bentoBlocks(36, complete: false);
    for (var i = 0; i < before.length; i++) {
      expect(after[i].start, before[i].start);
      expect(after[i].cells, same(before[i].cells));
    }
  });
}
