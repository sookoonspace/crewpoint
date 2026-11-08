/// `events/{id}/crews/{crewId}`: a working sub-team (Req 33). Only the server
/// writes it.
class CrewModel {
  const CrewModel({required this.id, required this.name});

  factory CrewModel.fromFirestore(String id, Map<String, dynamic> data) {
    final name = data['name'];
    return CrewModel(
      id: id,
      name: name is String && name.trim().isNotEmpty ? name : id,
    );
  }

  final String id;
  final String name;
}
