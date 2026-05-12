class DownloadChunkInfo {
  final int chunkIndex;
  final String chunkHash; // hex SHA-256 of the chunk
  final int chunkSize;
  final String peerId;
  final String token; // relay auth token for this chunk

  const DownloadChunkInfo({
    required this.chunkIndex,
    required this.chunkHash,
    required this.chunkSize,
    required this.peerId,
    required this.token,
  });

  factory DownloadChunkInfo.fromJson(Map<String, dynamic> json) =>
      DownloadChunkInfo(
        chunkIndex: _toInt(json['chunkIndex'] ?? json['chunk_index'] ?? json['index']),
        chunkHash:  _toStr(json['chunkHash']  ?? json['chunk_hash']  ?? json['hash'],  'chunkHash'),
        chunkSize:  _toInt(json['chunkSize']  ?? json['chunk_size']  ?? json['size']),
        peerId:     _toStr(json['peerId']     ?? json['peer_id'],                      'peerId'),
        token:      _toStr(json['token'],                                              'token'),
      );
}

class DownloadManifest {
  final String fileId;
  final String filename;
  final int filesize;
  final String merkleRoot; // hex SHA-256 of concatenated chunk hash bytes
  final List<DownloadChunkInfo> chunks;

  const DownloadManifest({
    required this.fileId,
    required this.filename,
    required this.filesize,
    required this.merkleRoot,
    required this.chunks,
  });

  factory DownloadManifest.fromJson(Map<String, dynamic> json) =>
      DownloadManifest(
        fileId:     _toStr(json['fileId']     ?? json['file_id'],     'fileId'),
        filename:   _toStr(json['filename'],                          'filename'),
        filesize:   _toInt(json['filesize']   ?? json['file_size']),
        merkleRoot: _toStr(json['merkleRoot'] ?? json['merkle_root'], 'merkleRoot'),
        chunks: (json['chunks'] as List<dynamic>)
            .map((e) => DownloadChunkInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

int _toInt(dynamic v) => v is int ? v : int.parse(v.toString());

String _toStr(dynamic v, String field) {
  if (v == null) throw Exception('Download manifest is missing required field: "$field"');
  return v.toString();
}
