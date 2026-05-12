import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/constants.dart';
import '../../core/deals/deal_service.dart';
import '../../core/files/download_service.dart';
import '../../core/files/file_record.dart';
import '../../core/files/files_service.dart';
import '../../core/files/proof_service.dart';
import '../../core/storage/secure_storage.dart';
import '../../widgets/twinkling_stars_painter.dart';


class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<FileRecord> _files = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  // fileId → current status string while a download is in progress
  final Map<String, String> _downloadStatus = {};
  // fileId → local file path for files downloaded this session
  final Map<String, String> _downloadedFiles = {};
  final Set<String> _deletingFiles = {};
  // track which STORED files we've already shown an escrow notification for
  final Set<String> _notifiedFiles = {};

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final files = await FilesService.getFiles();
      if (mounted) setState(() => _files = files);
      // Handle STORED files: auto-sign (if enabled) and show escrow notification
      final autoSignVal = await SecureStorage.read('auto_sign_deals');
      final autoSign = autoSignVal != 'false';
      for (final f in files) {
        if (f.status == 'STORED') {
          if (autoSign) {
            DealService.autoSignDealsForFile(f.fileId);
            DealService.retryFailedDealsForFile(f.fileId);
          }
          _maybeNotifyEscrow(f);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FileRecord> get _filtered => _query.isEmpty
      ? _files
      : _files
      .where((f) =>
      f.filename.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text("My Files"),
        centerTitle: false,
        elevation: 0,
        backgroundColor: kBackgroundColor,
        foregroundColor: kTextPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchFiles,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: TwinklingStars()),
          Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  style: const TextStyle(color: kTextPrimary),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: "Search files...",
                    hintStyle: TextStyle(color: kTextSecondary),
                    prefixIcon: Icon(Icons.search, color: kTextSecondary),
                    filled: true,
                    fillColor: kCardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // File list
              Expanded(child: _buildBody()),
            ],
          ),
        ],
      ),
    );
  }

  // Show a one-time SnackBar when a file first becomes STORED, showing peer escrow info
  Future<void> _maybeNotifyEscrow(FileRecord file) async {
    if (_notifiedFiles.contains(file.fileId)) return;
    _notifiedFiles.add(file.fileId);
    try {
      final deals = await DealService.fetchDealsForFile(file.fileId);
      if (!mounted || deals.isEmpty) return;
      final totalPeers = deals.length;
      final escrowWei = BigInt.tryParse(deals.first.peerEscrowWei) ?? BigInt.zero;
      final escrowDcld = escrowWei.toDouble() / 1e18;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'File stored across $totalPeers peer${totalPeers == 1 ? '' : 's'}. '
          'Peer escrow: ~${escrowDcld.toStringAsFixed(6)} DCLD/deal',
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 5),
      ));
    } catch (_) {}
  }

  Future<void> _confirmDelete(FileRecord file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181A20),
        title: const Text('Delete file?', style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${file.filename}" and all its stored replicas.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingFiles.add(file.fileId));
    try {
      await FilesService.deleteFile(file.fileId);
      if (mounted) {
        setState(() => _files.removeWhere((f) => f.fileId == file.fileId));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${file.filename}" deleted.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _deletingFiles.remove(file.fileId));
    }
  }

  Future<void> _downloadFile(FileRecord file) async {
    if (_downloadStatus.containsKey(file.fileId)) return;
    setState(() => _downloadStatus[file.fileId] = 'Starting...');

    try {
      final base = await getExternalStorageDirectory();
      final dir = Directory('${base!.path}/DeCloud');
      await dir.create(recursive: true);
      final outputPath = '${dir.path}/${file.filename}';

      await DownloadService.download(
        fileId: file.fileId,
        outputPath: outputPath,
        onProgress: (status) {
          if (mounted) setState(() => _downloadStatus[file.fileId] = status);
        },
      );

      if (mounted) {
        setState(() => _downloadedFiles[file.fileId] = outputPath);
        // Auto-open the file immediately after download
        _viewFile(outputPath, file.filename);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Downloaded: ${file.filename}'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () => _viewFile(outputPath, file.filename),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _downloadStatus.remove(file.fileId));
    }
  }

  // ── File viewer routing ──────────────────────────────────────────────────────

  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  static const _textExts  = {
    'txt', 'md', 'json', 'csv', 'xml', 'log', 'yaml', 'yml',
    'html', 'css', 'js', 'ts', 'dart', 'py', 'sh', 'toml', 'ini', 'env',
  };

  void _viewFile(String path, String filename) {
    final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : '';
    if (_imageExts.contains(ext)) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _ImageViewer(path: path, filename: filename),
      ));
    } else if (_textExts.contains(ext)) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _TextViewer(path: path, filename: filename),
      ));
    } else {
      OpenFile.open(path);
    }
  }

  void _showProofs(FileRecord file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ProofSheet(fileId: file.fileId, filename: file.filename),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _fetchFiles,
      color: Colors.cyanAccent,
      child: _buildScrollableContent(),
    );
  }

  Widget _buildScrollableContent() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 400,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        color: Colors.redAccent, size: 48),
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 8),
                    const Text(
                      'Pull down to retry',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _query.isEmpty
                        ? 'No files uploaded yet.'
                        : 'No results for "$_query".',
                    style: TextStyle(color: kTextSecondary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pull down to refresh',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _buildFileItem(_filtered[i]),
    );
  }

  Widget _buildFileItem(FileRecord file) {
    final sizeLabel      = _formatSize(file.filesize);
    final statusColor    = _statusColor(file.status);
    final downloadStatus = _downloadStatus[file.fileId];
    final isDownloading  = downloadStatus != null;
    final localPath      = _downloadedFiles[file.fileId];
    final isDownloaded   = localPath != null;

    // availability-driven visuals
    final tileColor = file.isAvailable ? kCardColor : kCardColor.withAlpha(100);
    final iconColor = file.isAvailable ? Colors.blueAccent : Colors.grey;
    final textColor = file.isAvailable ? kTextPrimary : kTextSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(file.isAvailable ? 90 : 40),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Row(
        children: [
          // ── File icon ────────────────────────────────────────────────────
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(35),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.insert_drive_file_rounded, color: iconColor),
          ),

          const SizedBox(width: 14),

          // ── File info (takes all remaining space) ─────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filename
                Text(
                  file.filename,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                // Size · chunks · replication
                Row(
                  children: [
                    Text(sizeLabel,
                        style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    Text(' · ',
                        style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    Text('${file.numberOfChunks} chunks',
                        style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    Text(' · ',
                        style: TextStyle(color: kTextSecondary, fontSize: 12)),
                    Text('×${file.replicationFactor}',
                        style: TextStyle(color: kTextSecondary, fontSize: 12)),
                  ],
                ),

                const SizedBox(height: 6),

                // Availability + expiry row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      file.isAvailable
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_rounded,
                      size: 12,
                      color: file.isAvailable
                          ? Colors.greenAccent
                          : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      file.isAvailable ? 'Available' : 'Unavailable',
                      style: TextStyle(
                        color: file.isAvailable
                            ? Colors.greenAccent
                            : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.timer_outlined, size: 11, color: kTextSecondary),
                    const SizedBox(width: 3),
                    Text(
                      _formatExpiry(file.endDate),
                      style: TextStyle(color: kTextSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Status badge + download + delete ─────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  file.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 30,
                width: 30,
                child: isDownloading
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isDownloaded
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.visibility_rounded, size: 22, color: Colors.cyanAccent),
                            tooltip: 'View file',
                            onPressed: () => _viewFile(localPath, file.filename),
                          )
                        : IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              Icons.download_rounded,
                              size: 22,
                              color: file.isAvailable ? Colors.blueAccent : Colors.grey,
                            ),
                            tooltip: file.isAvailable ? 'Download' : 'File unavailable',
                            onPressed: file.isAvailable ? () => _downloadFile(file) : null,
                          ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 28,
                width: 28,
                child: _deletingFiles.contains(file.fileId)
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                        tooltip: 'Delete file',
                        onPressed: () => _confirmDelete(file),
                      ),
              ),
            ],
          ),
        ],
        ), // end main Row
        if (downloadStatus != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  downloadStatus,
                  style: const TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        if (file.status == 'STORED') ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _showProofs(file),
            icon: const Icon(Icons.verified_user_outlined,
                size: 14, color: Colors.blueAccent),
            label: const Text('View Proofs',
                style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
        ], // end Column children
      ),
    );
  }

  String _formatExpiry(String endDateStr) {
    try {
      // Ensure the string is parsed as UTC — Postgres TIMESTAMP WITHOUT TIME ZONE
      // comes back without a Z suffix, so Dart would treat it as local time.
      final normalized = endDateStr.endsWith('Z') || endDateStr.contains('+')
          ? endDateStr
          : '${endDateStr}Z';
      final end = DateTime.parse(normalized).toLocal();
      final diff = end.difference(DateTime.now());
      if (diff.isNegative) return 'Expired';
      if (diff.inDays >= 365) return 'Expires in ${(diff.inDays / 365).floor()}y';
      if (diff.inDays >= 1)   return 'Expires in ${diff.inDays}d';
      if (diff.inHours >= 1)  return 'Expires in ${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
      if (diff.inMinutes >= 1) return 'Expires in ${diff.inMinutes}m ${diff.inSeconds.remainder(60)}s';
      return 'Expires in ${diff.inSeconds}s';
    } catch (_) {
      return '';
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ALLOCATED': return Colors.greenAccent;
      case 'PENDING':   return Colors.orangeAccent;
      case 'FAILED':    return Colors.redAccent;
      default:          return kTextSecondary;
    }
  }
}

// ── Image viewer ──────────────────────────────────────────────────────────────

class _ImageViewer extends StatelessWidget {
  final String path;
  final String filename;
  const _ImageViewer({required this.path, required this.filename});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(filename, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Open with...',
            onPressed: () => OpenFile.open(path),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8,
          child: Image.file(
            File(path),
            errorBuilder: (_, e, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
                const SizedBox(height: 12),
                Text('Could not load image', style: TextStyle(color: Colors.white38)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Text / code viewer ────────────────────────────────────────────────────────

class _TextViewer extends StatefulWidget {
  final String path;
  final String filename;
  const _TextViewer({required this.path, required this.filename});

  @override
  State<_TextViewer> createState() => _TextViewerState();
}

class _TextViewerState extends State<_TextViewer> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    File(widget.path).readAsString().then(
      (s) { if (mounted) setState(() => _content = s); },
      onError: (Object e) { if (mounted) setState(() => _error = e.toString()); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        foregroundColor: kTextPrimary,
        title: Text(widget.filename, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: 'Open with...',
            onPressed: () => OpenFile.open(widget.path),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            )
          : _content == null
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _content!,
                    style: const TextStyle(
                      color: Color(0xFFCDD6F4),
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.6,
                    ),
                  ),
                ),
    );
  }
}

// ── Proof bottom sheet ─────────────────────────────────────────────────────────

// Per-chunk entry within a peer's proof view
class _PeerChunkEntry {
  final int chunkIndex;
  final int intervalsVerified;
  final int intervalCount;
  final String status;
  const _PeerChunkEntry({
    required this.chunkIndex,
    required this.intervalsVerified,
    required this.intervalCount,
    required this.status,
  });
}

class _ProofSheet extends StatefulWidget {
  final String fileId;
  final String filename;
  const _ProofSheet({required this.fileId, required this.filename});

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  // peer address → list of chunk entries (sorted by chunkIndex)
  Map<String, List<_PeerChunkEntry>>? _byPeer;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final chunks = await ProofService.fetchProofs(widget.fileId);

      // Pivot chunk-centric → peer-centric
      final Map<String, List<_PeerChunkEntry>> map = {};
      for (final chunk in chunks) {
        for (final p in chunk.peers) {
          map.putIfAbsent(p.peerAddress, () => []);
          map[p.peerAddress]!.add(_PeerChunkEntry(
            chunkIndex: chunk.chunkIndex,
            intervalsVerified: p.intervalsVerified,
            intervalCount: p.intervalCount > 0 ? p.intervalCount : 10,
            status: p.status,
          ));
        }
      }
      // Sort each peer's chunks by index
      for (final list in map.values) {
        list.sort((a, b) => a.chunkIndex.compareTo(b.chunkIndex));
      }

      if (mounted) setState(() { _byPeer = map; _error = null; });
    } catch (e) {
      // Don't overwrite existing data on a transient poll error
      if (mounted && _byPeer == null) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final peers = _byPeer?.entries.toList() ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Storage Proofs',
              style: TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.filename,
              style: TextStyle(color: kTextSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.redAccent))
                  : _byPeer == null
                      ? const Center(child: CircularProgressIndicator())
                      : peers.isEmpty
                          ? Text(
                              'No proof data yet — deals must reach SETTLED status first.',
                              style: TextStyle(color: kTextSecondary, fontSize: 13),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: peers.length,
                              itemBuilder: (_, i) => _buildPeerCard(peers[i].key, peers[i].value),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerCard(String peerAddress, List<_PeerChunkEntry> chunks) {
    final addr = peerAddress.length >= 10
        ? '${peerAddress.substring(0, 6)}…${peerAddress.substring(peerAddress.length - 4)}'
        : peerAddress;

    // Use worst-case status for the peer-level chip
    final String overallStatus = _worstStatus(chunks.map((c) => c.status).toList());
    final chipColor = _statusColor(overallStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2028),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Peer header
          Row(
            children: [
              const Icon(Icons.computer_rounded, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(
                addr,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  overallStatus,
                  style: TextStyle(color: chipColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // One row per chunk
          ...chunks.map((c) => _buildChunkRow(c)),
        ],
      ),
    );
  }

  Widget _buildChunkRow(_PeerChunkEntry c) {
    final barColor = _barColor(c.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              'Chunk ${c.chunkIndex}',
              style: TextStyle(color: kTextSecondary, fontSize: 11),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(c.intervalCount, (i) {
                final filled = i < c.intervalsVerified;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 120 + i * 25),
                      height: 14,
                      decoration: BoxDecoration(
                        color: filled ? barColor : Colors.white10,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: filled ? barColor : Colors.white24,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${c.intervalsVerified}/${c.intervalCount}',
            style: TextStyle(color: kTextSecondary, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Color _barColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return Colors.green;
      case 'SLASHED':   return Colors.redAccent;
      default:          return Colors.blueAccent;
    }
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED': return Colors.green;
      case 'SLASHED':   return Colors.redAccent;
      case 'ACTIVE':    return Colors.blueAccent;
      default:          return Colors.grey;
    }
  }

  String _worstStatus(List<String> statuses) {
    if (statuses.any((s) => s.toUpperCase() == 'SLASHED'))   return 'SLASHED';
    if (statuses.any((s) => s.toUpperCase() == 'ACTIVE'))    return 'ACTIVE';
    if (statuses.any((s) => s.toUpperCase() == 'COMPLETED')) return 'COMPLETED';
    return statuses.isNotEmpty ? statuses.first : 'UNKNOWN';
  }
}