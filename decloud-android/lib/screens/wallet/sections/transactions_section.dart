import 'package:flutter/material.dart';
import '../../../widgets/transaction_tile.dart';

class TransactionsSection extends StatelessWidget {
  const TransactionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        TransactionTile(address: "0xA3f9...92C1", amount: 234.0),
        TransactionTile(address: "0x91bE...7D2A", amount: -1324.0),
      ],
    );
  }
}
