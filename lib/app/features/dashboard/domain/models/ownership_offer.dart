/// `events/{id}/ownership/offer`: the Owner has offered ownership to [to],
/// who has not accepted yet (Req 30). Only the server writes it.
class OwnershipOffer {
  const OwnershipOffer({required this.from, required this.to});

  /// Null for a missing or badly shaped document.
  static OwnershipOffer? fromFirestore(Map<String, dynamic>? data) {
    final from = data?['from'];
    final to = data?['to'];
    if (from is! String || to is! String) return null;
    return OwnershipOffer(from: from, to: to);
  }

  final String from;
  final String to;
}
