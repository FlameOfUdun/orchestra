/// Fixed-capacity append-only buffer; drops oldest on overflow.
final class RingBuffer<T> {
  RingBuffer(this.capacity) : assert(capacity > 0);

  final int capacity;
  final List<T?> _slots = <T?>[];
  int _start = 0;
  int _length = 0;

  int get length => _length;

  bool get isEmpty => _length == 0;

  void add(T value) {
    if (_slots.length < capacity) {
      _slots.add(value);
      _length++;
      return;
    }
    _slots[_start] = value;
    _start = (_start + 1) % capacity;
  }

  void clear() {
    _slots.clear();
    _start = 0;
    _length = 0;
  }

  /// Snapshot in chronological (oldest-first) order.
  List<T> toList() {
    final result = <T>[];
    for (int i = 0; i < _length; i++) {
      final value = _slots[(_start + i) % capacity];
      if (value != null) result.add(value);
    }
    return result;
  }
}
