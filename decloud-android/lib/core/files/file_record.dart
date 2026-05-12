class FileRecord {
  final String fileId;
  final String filename;
  final String fileHash;
  final int filesize;
  final String status;
  final int replicationFactor;
  final int numberOfChunks;
  final String createdAt;
  final String endDate;
  final bool isAvailable;

  const FileRecord({
    required this.fileId,
    required this.filename,
    required this.fileHash,
    required this.filesize,
    required this.status,
    required this.replicationFactor,
    required this.numberOfChunks,
    required this.createdAt,
    required this.endDate,
    required this.isAvailable,
  });

  factory FileRecord.fromJson(Map<String, dynamic> json) => FileRecord(
        fileId: json['fileId'] as String,
        filename: json['filename'] as String,
        fileHash: json['fileHash'] as String,
        filesize: _toInt(json['filesize']),
        status: json['status'] as String,
        replicationFactor: _toInt(json['replicationFactor']),
        numberOfChunks: _toInt(json['numberOfChunks']),
        createdAt: json['createdAt'] as String,
        endDate: json['endDate'] as String,
        isAvailable:json['isAvailable'] as bool? ?? false,
      );

  static int _toInt(dynamic v) =>
      v is int ? v : int.parse(v.toString());
}
