class DocumentModel {
  final String id;
  final String userId;
  final String imageUrl;
  final String documentType;
  final double? totalAmount;
  final String? keyDate;
  final String summary;
  final DateTime createdAt;

  DocumentModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.documentType,
    this.totalAmount,
    this.keyDate,
    required this.summary,
    required this.createdAt,
  });

  factory DocumentModel.fromMap(Map<String, dynamic> data, String id) {
    return DocumentModel(
      id: id,
      userId: data['userId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      documentType: data['documentType'] ?? 'Other',
      totalAmount: data['totalAmount'] != null ? (data['totalAmount'] as num).toDouble() : null,
      keyDate: data['keyDate'],
      summary: data['summary'] ?? '',
      createdAt: data['createdAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(data['createdAt']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'documentType': documentType,
      'totalAmount': totalAmount,
      'keyDate': keyDate,
      'summary': summary,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }
}
