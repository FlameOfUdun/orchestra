import 'package:flutter/material.dart';
import 'package:orchestra/inspector_export.dart';

import '../../theme/tokens.dart';

class JsonValueView extends StatelessWidget {
  final JsonValueDto? value;
  final int maxLines;

  const JsonValueView({super.key, required this.value, this.maxLines = 6});

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) {
      return const Text(
        '∅',
        style: TextStyle(color: Tokens.textMuted, fontFamily: Tokens.fontMono, fontSize: 12),
      );
    }
    if (v is OpaqueValueDto) {
      return _OpaqueView(value: v, maxLines: maxLines);
    }
    final direct = v as DirectValueDto;
    return SelectableText(
      _format(direct.value),
      maxLines: maxLines,
      style: const TextStyle(fontFamily: Tokens.fontMono, fontSize: 12),
    );
  }

  static String _format(Object? raw) {
    if (raw == null) return 'null';
    if (raw is String) return '"$raw"';
    if (raw is num || raw is bool) return raw.toString();
    return raw.toString();
  }
}

class _OpaqueView extends StatelessWidget {
  final OpaqueValueDto value;
  final int maxLines;

  const _OpaqueView({required this.value, required this.maxLines});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.typeName,
          style: const TextStyle(color: Tokens.textMuted, fontSize: 11),
        ),
        SelectableText(
          value.repr,
          maxLines: maxLines,
          style: const TextStyle(fontFamily: Tokens.fontMono, fontSize: 12),
        ),
        if (value.truncated)
          const Padding(
            padding: EdgeInsets.only(top: Tokens.spaceXs),
            child: Text(
              '… truncated',
              style: TextStyle(color: Tokens.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
