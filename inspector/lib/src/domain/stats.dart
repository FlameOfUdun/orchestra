final class InspectorStats {
  final int droppedFirings;
  final int gapsDetected;
  final int batchesReceived;

  const InspectorStats({
    this.droppedFirings = 0,
    this.gapsDetected = 0,
    this.batchesReceived = 0,
  });

  InspectorStats copyWith({
    int? droppedFirings,
    int? gapsDetected,
    int? batchesReceived,
  }) {
    return InspectorStats(
      droppedFirings: droppedFirings ?? this.droppedFirings,
      gapsDetected: gapsDetected ?? this.gapsDetected,
      batchesReceived: batchesReceived ?? this.batchesReceived,
    );
  }

  static const empty = InspectorStats();
}
