/// Fixed-capacity, append-only, immutable-on-write ring buffer.
///
/// Drops oldest when capacity exceeded. [push] returns a new instance so the
/// owning state stays referentially stable for selectors.
final class RingBuffer<T> {
  RingBuffer(this.capacity)
      : assert(capacity > 0),
        _slots = <T?>[],
        _start = 0,
        _length = 0;

  RingBuffer._internal({
    required this.capacity,
    required List<T?> slots,
    required int start,
    required int length,
  })  : _slots = slots,
        _start = start,
        _length = length;

  final int capacity;
  final List<T?> _slots;
  final int _start;
  final int _length;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isNotEmpty => _length > 0;

  T operator [](int index) {
    if (index < 0 || index >= _length) {
      throw RangeError.index(index, this, 'index', null, _length);
    }
    return _slots[(_start + index) % capacity] as T;
  }

  /// Returns a new buffer with [value] appended.
  RingBuffer<T> push(T value) {
    if (_slots.length < capacity) {
      final nextSlots = List<T?>.of(_slots)..add(value);
      return RingBuffer<T>._internal(
        capacity: capacity,
        slots: nextSlots,
        start: _start,
        length: _length + 1,
      );
    }
    final nextSlots = List<T?>.of(_slots);
    nextSlots[_start] = value;
    return RingBuffer<T>._internal(
      capacity: capacity,
      slots: nextSlots,
      start: (_start + 1) % capacity,
      length: _length,
    );
  }

  /// Returns a new buffer with each value in [values] appended in order.
  RingBuffer<T> pushAll(Iterable<T> values) {
    var result = this;
    for (final value in values) {
      result = result.push(value);
    }
    return result;
  }

  /// Snapshot in chronological (oldest-first) order.
  List<T> toList() {
    final out = <T>[];
    for (var i = 0; i < _length; i++) {
      final value = _slots[(_start + i) % capacity];
      if (value != null) out.add(value);
    }
    return out;
  }

  Iterable<T> get values sync* {
    for (var i = 0; i < _length; i++) {
      final value = _slots[(_start + i) % capacity];
      if (value != null) yield value;
    }
  }
}
