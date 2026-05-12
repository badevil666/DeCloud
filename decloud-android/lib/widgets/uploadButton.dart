import 'package:flutter/material.dart';
import 'dart:math' as math;

class UploadButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const UploadButton({super.key, required this.onTap, this.isLoading = false});

  @override
  State<UploadButton> createState() => _UploadButtonState();
}

class _UploadButtonState extends State<UploadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;

        // Animate gradient direction (Lottie-style)
        final begin = Alignment(
          math.cos(2 * math.pi * t),
          math.sin(2 * math.pi * t),
        );
        final end = Alignment(
          -math.cos(2 * math.pi * t),
          -math.sin(2 * math.pi * t),
        );

        return GestureDetector(
          onTap: widget.isLoading ? null : widget.onTap,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.isLoading ? 0.6 : 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: begin,
                  end: end,
                  colors: const [
                    Color(0xFF2CB1FF),
                    Color(0xFF6A5CFF),
                    Color(0xFFBB2BC5),
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF2CB1FF).withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.upload_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    widget.isLoading ? "Uploading..." : "Upload File",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
