class Contact {
  final String nodeId;    // '!1f8e42c9'
  String displayName;
  String? avatarEmoji;
  DateTime addedAt;

  Contact({
    required this.nodeId,
    required this.displayName,
    this.avatarEmoji,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'displayName': displayName,
    if (avatarEmoji != null) 'avatarEmoji': avatarEmoji,
    'addedAt': addedAt.toIso8601String(),
  };

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    nodeId: j['nodeId'] as String,
    displayName: j['displayName'] as String,
    avatarEmoji: j['avatarEmoji'] as String?,
    addedAt: DateTime.parse(j['addedAt'] as String),
  );

  String get displayLabel => avatarEmoji != null ? '$avatarEmoji $displayName' : displayName;
}
