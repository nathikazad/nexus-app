enum StudyDirection {
  frontToBack('front_to_back'),
  backToFront('back_to_front');

  const StudyDirection(this.storageKey);

  final String storageKey;

  static StudyDirection? fromStorageKey(String value) {
    for (final direction in values) {
      if (direction.storageKey == value) return direction;
    }
    return null;
  }
}
