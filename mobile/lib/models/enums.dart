/// Wire-format enums. Each parses the lowercase string the API uses.
enum PostStatus {
  draft,
  ready;

  static PostStatus parse(String? value) =>
      PostStatus.values.firstWhere((s) => s.name == value, orElse: () => PostStatus.draft);
}

enum TargetStatus {
  pending('Pending'),
  publishing('Publishing'),
  published('Published'),
  failed('Failed'),
  skipped('Skipped');

  const TargetStatus(this.label);
  final String label;

  static TargetStatus parse(String? value) =>
      TargetStatus.values.firstWhere((s) => s.name == value, orElse: () => TargetStatus.pending);
}

enum Platform {
  linkedin('LinkedIn'),
  instagram('Instagram'),
  whatsapp('WhatsApp'),
  youtube('YouTube'),
  x('X'),
  facebook('Facebook'),
  threads('Threads');

  const Platform(this.label);
  final String label;

  static Platform parse(String? value) =>
      Platform.values.firstWhere((p) => p.name == value, orElse: () => Platform.x);
}

enum PostingMode {
  manual,
  webhook;

  static PostingMode parse(String? value) =>
      PostingMode.values.firstWhere((m) => m.name == value, orElse: () => PostingMode.manual);
}

enum WebhookAuthType {
  none,
  basic;

  static WebhookAuthType parse(String? value) =>
      WebhookAuthType.values.firstWhere((a) => a.name == value, orElse: () => WebhookAuthType.none);
}

enum BulkPublishJobStatus {
  running,
  completed,
  cancelled;

  static BulkPublishJobStatus parse(String? value) =>
      BulkPublishJobStatus.values.firstWhere((s) => s.name == value, orElse: () => BulkPublishJobStatus.running);
}

enum BulkPublishItemStatus {
  pending('Queued'),
  publishing('Posting now'),
  published('Published'),
  partial('Partly failed'),
  failed('Failed'),
  skipped('Skipped'),
  cancelled('Cancelled');

  const BulkPublishItemStatus(this.label);
  final String label;

  static BulkPublishItemStatus parse(String? value) =>
      BulkPublishItemStatus.values.firstWhere((s) => s.name == value, orElse: () => BulkPublishItemStatus.pending);
}
