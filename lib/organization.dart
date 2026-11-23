/// Represents an organization (school, college, business, or custom entity).
class Organization {
  final int? id;
  final String name;
  final String? address;
  final String? country;
  final String type; // 'school', 'college', 'business', 'organization'
  final String code; // 9-character code (e.g. ABC12D34E)

  Organization({
    this.id,
    required this.name,
    this.address,
    this.country,
    required this.type,
    required this.code,
  });

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String?,
      country: map['country'] as String?,
      type: map['type'] as String,
      code: map['code'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'country': country,
      'type': type,
      'code': code,
    };
  }
}
