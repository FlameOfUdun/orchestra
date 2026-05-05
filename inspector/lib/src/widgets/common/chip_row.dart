import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

class SingleChipRow<T> extends StatelessWidget {
  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T?> onSelected;

  const SingleChipRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Tokens.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: Tokens.spaceSm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: Tokens.spaceSm),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: selected == null,
                    onSelected: (_) => onSelected(null),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                ...options.map((opt) => Padding(
                      padding: const EdgeInsets.only(right: Tokens.spaceSm),
                      child: FilterChip(
                        label: Text(labelOf(opt)),
                        selected: selected == opt,
                        onSelected: (_) => onSelected(opt),
                        visualDensity: VisualDensity.compact,
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MultiChipRow<T> extends StatelessWidget {
  final String label;
  final List<T> options;
  final Set<T> selected;
  final String Function(T) labelOf;
  final ValueChanged<Set<T>> onChanged;

  const MultiChipRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(color: Tokens.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: Tokens.spaceSm),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((opt) {
                final isSelected = selected.contains(opt);
                return Padding(
                  padding: const EdgeInsets.only(right: Tokens.spaceSm),
                  child: FilterChip(
                    label: Text(labelOf(opt)),
                    selected: isSelected,
                    onSelected: (_) {
                      final next = Set<T>.of(selected);
                      if (isSelected) {
                        next.remove(opt);
                      } else {
                        next.add(opt);
                      }
                      onChanged(next);
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
