import 'package:flutter/material.dart';

class TransactionTile extends StatelessWidget {
  final String address;
  final double amount;

  const TransactionTile({
    super.key,
    required this.address,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final incoming = amount >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: incoming ? Colors.green : Colors.red,
            child: Icon(
              incoming ? Icons.call_received : Icons.call_made,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  incoming ? "Received" : "Sent",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  address,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "${incoming ? '+' : ''}${amount.toStringAsFixed(2)} DCLD",
            style: TextStyle(
              color: incoming ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
