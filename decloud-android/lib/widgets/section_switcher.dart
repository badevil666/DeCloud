import 'package:flutter/material.dart';

enum WalletSection { transactions, contracts }

class SectionSwitcher extends StatelessWidget {
  final WalletSection active;
  final ValueChanged<WalletSection> onChange;

  const SectionSwitcher({
    super.key,
    required this.active,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _button("Transactions", WalletSection.transactions),
          _button("Smart Contracts", WalletSection.contracts),
        ],
      ),
    );
  }

  Widget _button(String label, WalletSection section) {
    final selected = active == section;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChange(section),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
