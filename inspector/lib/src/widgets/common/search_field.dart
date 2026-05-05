import 'dart:async';

import 'package:flutter/material.dart';

class SearchField extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final Duration debounce;

  const SearchField({
    super.key,
    this.hintText = 'Search...',
    required this.onChanged,
    this.debounce = const Duration(milliseconds: 250),
  });

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _controller = TextEditingController();
  Timer? _debounceTimer;
  String _lastFired = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounce, () {
      if (value == _lastFired) return;
      _lastFired = value;
      widget.onChanged(value);
    });
    setState(() {}); // refresh suffix icon
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _controller.clear();
                  _onChanged('');
                },
              ),
        isDense: true,
      ),
    );
  }
}
