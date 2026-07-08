import 'package:alfred_client/utils/list_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // spec: PROM-LIST-FILTER-001, SURF-CONTACTS-002, PROM-PERSONAL-CONTACTS-008
  group('filterByQueryFields', () {
    test('filters by substring case-insensitive across fields', () {
      final items = [
        _Item(name: 'Alice', preview: 'ciao', address: 'alice'),
        _Item(name: 'Bob', preview: 'hey', address: 'bob'),
      ];

      final filtered = filterByQueryFields(
        items,
        'CIAO',
        (item) => [item.name, item.preview, item.address],
      );

      expect(filtered.map((i) => i.name), ['Alice']);
    });

    test('returns all items when query is empty', () {
      final items = [_Item(name: 'Alice', preview: 'ciao', address: 'alice')];

      expect(
        filterByQueryFields(items, '', (item) => [item.name]).length,
        1,
      );
    });
  });

  group('filterByQuery', () {
    test('filters single searchable field', () {
      final items = [
        _Item(name: 'Alice', preview: '', address: ''),
        _Item(name: 'Bob', preview: '', address: ''),
      ];

      final filtered = filterByQuery(
        items,
        'bob',
        (item) => item.name,
      );

      expect(filtered.map((i) => i.name), ['Bob']);
    });
  });
}

class _Item {
  _Item({required this.name, required this.preview, required this.address});

  final String name;
  final String preview;
  final String address;
}
