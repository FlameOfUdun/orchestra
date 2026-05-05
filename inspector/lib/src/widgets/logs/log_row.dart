import 'package:flutter/material.dart';
import 'package:orchestra/inspector_export.dart';

import '../../domain/log_entry.dart';
import '../../theme/tokens.dart';

class LogRow extends StatelessWidget {
  final LogEntry log;
  final bool related;
  final VoidCallback? onSystemTap;
  final VoidCallback? onOrchestrationTap;

  const LogRow({
    super.key,
    required this.log,
    required this.related,
    this.onSystemTap,
    this.onOrchestrationTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(log.level);
    return Card(
      margin: const EdgeInsets.only(bottom: Tokens.spaceSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: related ? Tokens.selectionBorder : Colors.transparent,
          width: related ? 1.5 : 0,
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_levelIcon(log.level), color: color, size: 18),
        ),
        title: Text(
          log.message,
          style: const TextStyle(fontSize: 13, fontFamily: Tokens.fontMono),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              _formatTime(log.tsMicros),
              style: const TextStyle(color: Tokens.textMuted, fontSize: 11),
            ),
            if (log.orchestrationId != null) ...[
              const SizedBox(width: Tokens.spaceSm),
              _MiniBadge(
                label: log.orchestrationId!,
                onTap: onOrchestrationTap,
              ),
            ],
            if (log.systemId != null) ...[
              const SizedBox(width: Tokens.spaceSm),
              _MiniBadge(label: log.systemId!, onTap: onSystemTap),
            ],
          ],
        ),
        children: [
          if (log.stack != null && log.stack!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Tokens.spaceMd),
              margin: const EdgeInsets.fromLTRB(
                Tokens.spaceLg,
                0,
                Tokens.spaceLg,
                Tokens.spaceLg,
              ),
              decoration: BoxDecoration(
                color: Tokens.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                log.stack!,
                style: const TextStyle(fontFamily: Tokens.fontMono, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  static Color _levelColor(LogLevelDto l) => switch (l) {
        LogLevelDto.verbose => Tokens.logVerbose,
        LogLevelDto.debug => Tokens.logDebug,
        LogLevelDto.info => Tokens.logInfo,
        LogLevelDto.warning => Tokens.logWarning,
        LogLevelDto.error => Tokens.logError,
        LogLevelDto.fatal => Tokens.logFatal,
      };

  static IconData _levelIcon(LogLevelDto l) => switch (l) {
        LogLevelDto.verbose => Icons.more_horiz,
        LogLevelDto.debug => Icons.bug_report_outlined,
        LogLevelDto.info => Icons.info_outline,
        LogLevelDto.warning => Icons.warning_amber_outlined,
        LogLevelDto.error => Icons.error_outline,
        LogLevelDto.fatal => Icons.dangerous_outlined,
      };

  static String _formatTime(int micros) {
    final t = DateTime.fromMicrosecondsSinceEpoch(micros);
    return '${_pad2(t.hour)}:${_pad2(t.minute)}:${_pad2(t.second)}.${_pad3(t.millisecond)}';
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
  static String _pad3(int n) => n.toString().padLeft(3, '0');
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _MiniBadge({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Tokens.elevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: onTap != null ? Tokens.textPrimary : Tokens.textSecondary,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
