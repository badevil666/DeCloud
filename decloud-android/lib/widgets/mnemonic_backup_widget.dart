import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class MnemonicBackupWidget extends StatefulWidget {
  final String mnemonic;
  final VoidCallback onConfirmed;

  const MnemonicBackupWidget({
    super.key,
    required this.mnemonic,
    required this.onConfirmed,
  });

  @override
  State<MnemonicBackupWidget> createState() => _MnemonicBackupWidgetState();
}

class _MnemonicBackupWidgetState extends State<MnemonicBackupWidget> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.mnemonic));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final words = widget.mnemonic.split(' ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Your Recovery Phrase',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Write these words down in order and store them somewhere safe. Anyone with this phrase can access your wallet.',
            style: TextStyle(color: kTextSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kDividerColor),
            ),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: words.length,
              itemBuilder: (context, i) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: kTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        words[i],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 18,
            ),
            label: Text(_copied ? 'Copied!' : 'Copy to Clipboard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: kDividerColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: widget.onConfirmed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              "I've Saved My Phrase",
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
