class ProviderStats {
  final int tasksThisMonth;
  final int totalTasks;
  final double totalEarned;
  final double averageRating;
  final int completedTasks;
  final int pendingTasks;

  ProviderStats({
    this.tasksThisMonth = 0,
    this.totalTasks = 0,
    this.totalEarned = 0.0,
    this.averageRating = 0.0,
    this.completedTasks = 0,
    this.pendingTasks = 0,
  });

  factory ProviderStats.fromMap(Map<String, dynamic> map) {
    return ProviderStats(
      tasksThisMonth: map['tasksThisMonth'] ?? 0,
      totalTasks: map['totalTasks'] ?? 0,
      totalEarned: (map['totalEarned'] ?? 0.0).toDouble(),
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      completedTasks: map['completedTasks'] ?? 0,
      pendingTasks: map['pendingTasks'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tasksThisMonth': tasksThisMonth,
      'totalTasks': totalTasks,
      'totalEarned': totalEarned,
      'averageRating': averageRating,
      'completedTasks': completedTasks,
      'pendingTasks': pendingTasks,
    };
  }
} 