import 'package:flutter/material.dart';

import '../domain/connection_state.dart';
import '../theme/tokens.dart';

class ConnectionBanner extends StatelessWidget {
  final InspectorConnectionState state;
  final VoidCallback? onRetry;

  const ConnectionBanner({super.key, required this.state, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final s = state;
    if (s is Connected) return const SizedBox.shrink();

    final (color, icon, label) = switch (s) {
      Connecting() => (Tokens.connConnecting, Icons.sync, 'Connecting…'),
      Disconnected() => (Tokens.connDisconnected, Icons.circle_outlined, 'Disconnected'),
      Stale() => (Tokens.connStale, Icons.timer_off_outlined, 'No events received recently'),
      Errored(reason: final reason) => (Tokens.connError, Icons.error_outline, reason),
      Connected() => (Tokens.connConnected, Icons.check_circle, 'Connected'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.spaceLg, vertical: Tokens.spaceSm),
      color: color.withValues(alpha: 0.12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: Tokens.spaceSm),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onRetry != null && (s is Errored || s is Stale || s is Disconnected))
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: color,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}
