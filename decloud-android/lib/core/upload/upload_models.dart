import 'dart:typed_data';

class ProcessResult {
  final FileManifest manifest;
  final List<Uint8List> chunks;

  const ProcessResult({required this.manifest, required this.chunks});
}

class PeerAssignment {
  final String token;
  final List<int> chunkIndexes;

  const PeerAssignment({required this.token, required this.chunkIndexes});

  factory PeerAssignment.fromJson(Map<String, dynamic> json) => PeerAssignment(
        token: json['token'] as String,
        chunkIndexes: (json['chunkIndexes'] as List<dynamic>).cast<int>(),
      );
}

/// Phase 1 response — POST /client/upload (202)
class AllocateResponse {
  final String sessionId;
  final String fileId;
  final String merkleRoot;
  final Map<String, PeerAssignment> peers;
  final int expiresIn; // seconds until session expires

  const AllocateResponse({
    required this.sessionId,
    required this.fileId,
    required this.merkleRoot,
    required this.peers,
    required this.expiresIn,
  });

  factory AllocateResponse.fromJson(Map<String, dynamic> json) => AllocateResponse(
        sessionId: json['sessionId'] as String,
        fileId: json['fileId'] as String,
        merkleRoot: json['merkleRoot'] as String,
        peers: (json['peers'] as Map<String, dynamic>).map(
          (id, v) => MapEntry(id, PeerAssignment.fromJson(v as Map<String, dynamic>)),
        ),
        expiresIn: json['expiresIn'] as int,
      );
}

/// Phase 2 response — POST /client/upload/confirm (201)
class ConfirmResponse {
  final String fileId;
  final String merkleRoot;
  final String status;
  final Map<String, PeerAssignment> peers;

  const ConfirmResponse({
    required this.fileId,
    required this.merkleRoot,
    required this.status,
    required this.peers,
  });

  factory ConfirmResponse.fromJson(Map<String, dynamic> json) => ConfirmResponse(
        fileId: json['fileId'] as String,
        merkleRoot: json['merkleRoot'] as String,
        status: json['status'] as String,
        peers: (json['peers'] as Map<String, dynamic>).map(
          (id, v) => MapEntry(id, PeerAssignment.fromJson(v as Map<String, dynamic>)),
        ),
      );
}

class NonceHash {
  final String nonce; // hex-encoded 32-byte random nonce
  final String hash;  // hex SHA-256(chunk_bytes ++ nonce_bytes)

  const NonceHash({required this.nonce, required this.hash});

  Map<String, dynamic> toJson() => {'nonce': nonce, 'hash': hash};
}

class ChunkInfo {
  final String hash;             // hex SHA-256 of the chunk
  final int size;                // byte length of the chunk
  final List<NonceHash> nonces;  // 10 nonce+hash pairs

  const ChunkInfo({required this.hash, required this.size, required this.nonces});

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'size': size,
        'nonces': nonces.map((n) => n.toJson()).toList(),
      };
}

class FileManifest {
  final String filename;
  final int filesize;
  final String fileHash;
  final int numberOfChunks;
  final int replicationFactor;
  final List<ChunkInfo> chunkInfo;
  final DateTime endDate;

  const FileManifest({
    required this.filename,
    required this.filesize,
    required this.fileHash,
    required this.numberOfChunks,
    required this.replicationFactor,
    required this.chunkInfo,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'filesize': filesize,
        'fileHash': fileHash,
        'numberOfChunks': numberOfChunks,
        'replicationFactor': replicationFactor,
        'endDate': endDate.toUtc().toIso8601String(),
        'chunkInfo': chunkInfo.map((c) => c.toJson()).toList(),
      };
}
