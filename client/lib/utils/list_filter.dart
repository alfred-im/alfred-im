List<T> filterByQuery<T>(
  List<T> items,
  String query,
  String Function(T item) searchableText,
) {
  if (query.isEmpty) return items;
  final normalized = query.toLowerCase();
  return items
      .where((item) => searchableText(item).toLowerCase().contains(normalized))
      .toList();
}

List<T> filterByQueryFields<T>(
  List<T> items,
  String query,
  Iterable<String> Function(T item) searchableFields,
) {
  if (query.isEmpty) return items;
  final normalized = query.toLowerCase();
  return items.where((item) {
    return searchableFields(item)
        .any((field) => field.toLowerCase().contains(normalized));
  }).toList();
}
