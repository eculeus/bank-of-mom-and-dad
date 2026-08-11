const celebrateAfter = Duration(hours: 1);

bool shouldCelebrate(DateTime? lastSeenAt, DateTime now) =>
    lastSeenAt == null || now.difference(lastSeenAt) >= celebrateAfter;

bool isNewTransaction(DateTime? txCreatedAt, DateTime? prevSeenAt) =>
    txCreatedAt != null && prevSeenAt != null && txCreatedAt.isAfter(prevSeenAt);
