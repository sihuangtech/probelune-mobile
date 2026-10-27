import 'package:flutter/material.dart';

import '../l10n.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'healthy' || 'success' => const Color(0xff087f73),
      'down' || 'failed' || 'failure' => const Color(0xffbd4141),
      'partial' || 'pending' => const Color(0xffaa750e),
      _ => const Color(0xff63747a),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText(context, status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
