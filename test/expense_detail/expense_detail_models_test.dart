import 'package:chexiaoji_app/features/expense_detail/domain/expense_detail_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'expense_detail_test_helpers.dart';

void main() {
  group('ExpenseDetail.fromRecord', () {
    test('支出推导 completed，并保留备注快照', () {
      final detail = ExpenseDetail.fromRecord(buildRecord(note: '快照备注'));

      expect(detail.status, ExpenseStatus.completed);
      expect(detail.note, '快照备注');
      expect(detail.tags, isEmpty);
      expect(detail.vehicleBound, isTrue);
    });

    test('负数金额推导 refunded', () {
      final detail = ExpenseDetail.fromRecord(buildRecord(amountCents: -5110));

      expect(detail.status, ExpenseStatus.refunded);
    });
  });

  test('copyWith 支持清空备注', () {
    final detail = ExpenseDetail.fromRecord(buildRecord(note: '原备注'));
    final cleared = detail.copyWith(clearNote: true);

    expect(cleared.note, isNull);
    expect(detail.note, '原备注');
  });

  group('sanitizeTags', () {
    test('trim、去 #、去空、去重并保持顺序', () {
      final tags = sanitizeTags([
        ' #日常补能 ',
        '日常补能',
        '',
        '##谷电错峰',
        '  ',
      ]);

      expect(tags, ['日常补能', '谷电错峰']);
    });

    test('限制长度与数量', () {
      final tags = sanitizeTags([
        '一二三四五六七八九十十一',
        ...List<String>.generate(10, (index) => '标签$index'),
      ]);

      expect(tags.length, ExpenseDetailRules.maxTags);
      expect(tags.first.runes.length, ExpenseDetailRules.maxTagLength);
    });
  });

  group('normalizeNote', () {
    test('空串与全空格转为 null', () {
      expect(normalizeNote(''), isNull);
      expect(normalizeNote('   \n '), isNull);
    });

    test('超长截断到 200 字', () {
      final note = normalizeNote('备' * 260);

      expect(note, isNotNull);
      expect(note!.runes.length, ExpenseDetailRules.maxNoteLength);
    });
  });
}
