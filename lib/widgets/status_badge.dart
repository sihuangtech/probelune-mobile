import 'package:flutter/material.dart';

import '../localization.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (status) {
      'healthy' ||
      'success' => dark ? const Color(0xff72dbc0) : const Color(0xff087f73),
      'down' ||
      'failed' ||
      'failure' => dark ? const Color(0xffffaaa6) : const Color(0xffbd4141),
      'partial' ||
      'pending' => dark ? const Color(0xffffd17b) : const Color(0xffaa750e),
      _ => dark ? const Color(0xffb7c9ce) : const Color(0xff63747a),
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
