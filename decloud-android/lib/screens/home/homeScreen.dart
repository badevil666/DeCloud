import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/files/files_service.dart';
import '../../widgets/twinkling_stars_painter.dart';
import '../wallet/wallet_gate_screen.dart';
import '../files/filesScreen.dart';
import '../upload/uploadScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _fileCount = 0;
  int _totalBytes = 0;
  bool _loadingStorage = true;

  final actions = [
    {"icon": Icons.upload_file, "label": "Upload", "page": UploadScreen()},
    {"icon": Icons.history, "label": "Recent Files", "page": FilesScreen()},
    {
      "icon": Icons.swap_horiz,
      "label": "Transactions",
      "page": WalletGateScreen(),
    },
    {
      "icon": Icons.description,
      "label": "Contracts",
      "page": WalletGateScreen(),
    },
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
    _loadStorageUsage();
  }

  Future<void> _loadStorageUsage() async {
    try {
      final files = await FilesService.getFiles();
      final total = files.fold<int>(0, (sum, f) => sum + f.filesize);
      if (mounted) {
        setState(() {
          _fileCount = files.length;
          _totalBytes = total;
          _loadingStorage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStorage = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: TwinklingStars()),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final t = Curves.easeOut.transform(_controller.value);
                    return Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * 30),
                        child: child,
                      ),
                    );
                  },
                  child: const Text(
                    "Decloud",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: Color.fromARGB(200, 200, 200, 200),
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                // Storage card
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final scale = Curves.easeOutBack.transform(
                      _controller.value.clamp(0.0, 1.0),
                    );
                    return Transform.scale(scale: scale, child: child);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: kPrimaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withAlpha(150),
                          blurRadius: 25,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: _loadingStorage
                        ? const SizedBox(
                            height: 60,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Storage Used",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatBytes(_totalBytes),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_fileCount ${_fileCount == 1 ? 'file' : 'files'} stored',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 36),

                const Text(
                  "Quick Actions",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color.fromARGB(255, 200, 200, 200),
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(actions.length, (i) {
                    final action = actions[i];
                    return _animatedAction(
                      i,
                      action["icon"] as IconData,
                      action["label"] as String,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => action["page"] as Widget,
                          ),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _animatedAction(
    int index,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final delay = index * 0.2;
        final raw = ((_controller.value - delay) / 0.6).clamp(0.0, 1.0);
        final scale = Curves.easeOutBack.transform(raw);
        return Transform.scale(
          scale: scale,
          child: Opacity(opacity: raw, child: child),
        );
      },
      child: _buildActionItem(icon, label, onTap),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 250, 248, 248).withAlpha(200),
                  blurRadius: 14,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    kPrimaryGradient.createShader(bounds),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
