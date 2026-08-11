enum LearningStatus {
  notStarted('not_started'),
  learning('learning'),
  learnt('learnt');

  const LearningStatus(this.storageValue);

  final String storageValue;

  bool get isRecallEligible => this != LearningStatus.notStarted;

  static LearningStatus fromStorage(Object? value) => switch (value) {
    'learning' => LearningStatus.learning,
    'learnt' => LearningStatus.learnt,
    _ => LearningStatus.notStarted,
  };
}
