// lib/Model/contact_model.dart

class ContactModel {
  final String id;
  final String displayName;
  final List<PhoneNumber> phones;
  final List<ContactEmail> emails;
  final String? photoBytes;

  ContactModel({
    required this.id,
    required this.displayName,
    this.phones = const [],
    this.emails = const [],
    this.photoBytes,
  });

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      phones: (map['phones'] as List?)
              ?.map((phone) => PhoneNumber.fromMap(phone))
              .toList() ??
          [],
      emails: (map['emails'] as List?)
              ?.map((email) => ContactEmail.fromMap(email))
              .toList() ??
          [],
      photoBytes: map['photoBytes'],
    );
  }
}

class PhoneNumber {
  final String number;
  final String? label;

  PhoneNumber({
    required this.number,
    this.label,
  });

  factory PhoneNumber.fromMap(Map<String, dynamic> map) {
    return PhoneNumber(
      number: map['number'] ?? '',
      label: map['label'],
    );
  }
}

class ContactEmail {
  final String address;
  final String? label;

  ContactEmail({
    required this.address,
    this.label,
  });

  factory ContactEmail.fromMap(Map<String, dynamic> map) {
    return ContactEmail(
      address: map['address'] ?? '',
      label: map['label'],
    );
  }
}
