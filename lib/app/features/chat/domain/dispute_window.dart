const int defaultDisputeWindowDays = 30;

/// The event's dispute window, matching `disputeSettlement` on the server.
int disputeWindowDaysFrom(Map<String, dynamic>? settings) {
  final configured = settings?['disputeWindowDays'];
  return configured is num && configured > 0
      ? configured.toInt()
      : defaultDisputeWindowDays;
}

/// Whether a settlement can still be disputed. The server has the final say.
bool isDisputeWindowOpen({
  required DateTime settledAt,
  required int windowDays,
  required DateTime now,
}) => !now.isAfter(settledAt.add(Duration(days: windowDays)));
