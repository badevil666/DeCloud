import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:hex/hex.dart';
import 'upload_models.dart';

const int _noncesPerChunk = 10;
const int _nonceBytes = 32;

/// Same as [processFile] but runs on the calling isolate and emits progress
/// events so the UI can show live step-by-step status.
///
/// Progress event strings:
///   'reading'          — reading file bytes
///   'chunking:N'       — split into N chunks
///   'hash:i:N'         — hashing chunk i of N
///   'nonces:i:N'       — generating 10 proof nonces for chunk i of N
///   'merkle'           — building Merkle tree / manifest
Future<ProcessResult> processFileWithProgress(
  String filePath,
  int numberOfChunks,
  int replicationFactor,
  DateTime endDate,
  void Function(String) onProgress,
) async {
  onProgress('reading');
  final file = File(filePath);
  final bytes = await file.readAsBytes();
  final filesize = bytes.length;
  final filename = filePath.split('/').last;

  final sha256 = Sha256();
  final fileHashBytes = (await sha256.hash(bytes)).bytes;
  final fileHash = HEX.encode(fileHashBytes);

  final clampedChunks = max(1, numberOfChunks);
  final chunkSize = (filesize / clampedChunks).ceil();
  final chunks = <Uint8List>[];
  for (int i = 0; i < clampedChunks; i++) {
    final start = i * chunkSize;
    if (start >= filesize) break;
    final end = min(start + chunkSize, filesize);
    chunks.add(bytes.sublist(start, end));
  }

  onProgress('chunking:${chunks.length}');

  final rng = Random.secure();
  final chunkInfos = <ChunkInfo>[];
  final total = chunks.length;

  for (int idx = 0; idx < chunks.length; idx++) {
    final chunk = chunks[idx];

    onProgress('hash:${idx + 1}:$total');
    final chunkHashBytes = (await sha256.hash(chunk)).bytes;
    final chunkHash = HEX.encode(chunkHashBytes);

    onProgress('nonces:${idx + 1}:$total');
    final nonces = <NonceHash>[];
    for (int i = 0; i < _noncesPerChunk; i++) {
      final nonce = Uint8List.fromList(
        List.generate(_nonceBytes, (_) => rng.nextInt(256)),
      );
      final combined = Uint8List.fromList([...chunk, ...nonce]);
      final combinedHashBytes = (await sha256.hash(combined)).bytes;
      nonces.add(NonceHash(
        nonce: HEX.encode(nonce),
        hash: HEX.encode(combinedHashBytes),
      ));
    }

    chunkInfos.add(ChunkInfo(hash: chunkHash, size: chunk.length, nonces: nonces));
  }

  onProgress('merkle');

  final manifest = FileManifest(
    filename: filename,
    filesize: filesize,
    fileHash: fileHash,
    numberOfChunks: chunks.length,
    replicationFactor: replicationFactor,
    chunkInfo: chunkInfos,
    endDate: endDate,
  );

  return ProcessResult(manifest: manifest, chunks: chunks);
}

/// Runs entirely in the caller's isolate — call via [Isolate.run] or [compute]
/// to keep the UI thread free for large files.
/// Returns both the [FileManifest] and the raw [chunks] so the caller can
/// stream them to peers without re-reading the file.
Future<ProcessResult> processFile(
  String filePath,
  int numberOfChunks,
  int replicationFactor,
  DateTime endDate,
) async {
  final file = File(filePath);
  final bytes = await file.readAsBytes();
  final filesize = bytes.length;
  final filename = filePath.split('/').last;

  final sha256 = Sha256();

  // 1. Hash entire file
  final fileHashBytes = (await sha256.hash(bytes)).bytes;
  final fileHash = HEX.encode(fileHashBytes);

  // 2. Split into equal chunks
  final clampedChunks = max(1, numberOfChunks);
  final chunkSize = (filesize / clampedChunks).ceil();
  final chunks = <Uint8List>[];
  for (int i = 0; i < clampedChunks; i++) {
    final start = i * chunkSize;
    if (start >= filesize) break;
    final end = min(start + chunkSize, filesize);
    chunks.add(bytes.sublist(start, end));
  }

  // 3. Hash each chunk + generate 10 nonces per chunk
  final rng = Random.secure();
  final chunkInfos = <ChunkInfo>[];

  for (final chunk in chunks) {
    final chunkHashBytes = (await sha256.hash(chunk)).bytes;
    final chunkHash = HEX.encode(chunkHashBytes);

    final nonces = <NonceHash>[];
    for (int i = 0; i < _noncesPerChunk; i++) {
      final nonce = Uint8List.fromList(
        List.generate(_nonceBytes, (_) => rng.nextInt(256)),
      );
      final combined = Uint8List.fromList([...chunk, ...nonce]);
      final combinedHashBytes = (await sha256.hash(combined)).bytes;
      nonces.add(NonceHash(
        nonce: HEX.encode(nonce),
        hash: HEX.encode(combinedHashBytes),
      ));
    }

    chunkInfos.add(ChunkInfo(hash: chunkHash, size: chunk.length, nonces: nonces));
  }

  final manifest = FileManifest(
    filename: filename,
    filesize: filesize,
    fileHash: fileHash,
    numberOfChunks: chunks.length,
    replicationFactor: replicationFactor,
    chunkInfo: chunkInfos,
    endDate: endDate,
  );

  return ProcessResult(manifest: manifest, chunks: chunks);
}
