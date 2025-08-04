import 'package:flutter/material.dart';

class TipCard extends StatelessWidget {
  final String tipText;

  const TipCard({super.key, required this.tipText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tipText, style: TextStyle(color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }
}
