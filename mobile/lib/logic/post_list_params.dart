const int defaultPageSize = 20;
const int maxPageSize = 100;
const List<int> pageSizeOptions = [10, 20, 50];

int parsePageParam(String? value) {
  final page = int.tryParse(value ?? '');
  if (page == null || page < 0) {
    return 0;
  }
  return page;
}

int parseSizeParam(String? value) {
  final size = int.tryParse(value ?? '');
  if (size == null || size < 1 || size > maxPageSize) {
    return defaultPageSize;
  }
  return size;
}
