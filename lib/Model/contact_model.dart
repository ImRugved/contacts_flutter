// lib/Model/contact_model.dart

class ContactModel {
  final String id;
  final String displayName;
  final String? prefix; // Mr., Mrs., etc.
  final String? suffix; // Jr., Sr., etc.
  final String? firstName;
  final String? lastName;
  final List<PhoneNumber> phones;
  final List<ContactEmail> emails;
  final List<ContactAddress> addresses;
  final List<ContactEvent> events; // birthdays, anniversaries
  final List<ContactWebsite> websites;
  final List<ContactSocialMedia> socialAccounts;
  final List<ContactRelation> relations; // family, friends, etc.
  final List<ContactGroup> groups;
  final String? company;
  final String? jobTitle;
  final String? department;
  final String? note;
  final String? photoBytes;
  final bool isStarred;

  ContactModel({
    required this.id,
    required this.displayName,
    this.prefix,
    this.suffix,
    this.firstName,
    this.lastName,
    this.phones = const [],
    this.emails = const [],
    this.addresses = const [],
    this.events = const [],
    this.websites = const [],
    this.socialAccounts = const [],
    this.relations = const [],
    this.groups = const [],
    this.company,
    this.jobTitle,
    this.department,
    this.note,
    this.photoBytes,
    this.isStarred = false,
  });

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] ?? '',
      displayName: map['displayName'] ?? '',
      prefix: map['prefix'],
      suffix: map['suffix'],
      firstName: map['firstName'],
      lastName: map['lastName'],
      phones: (map['phones'] as List?)
              ?.map((phone) => PhoneNumber.fromMap(phone))
              .toList() ??
          [],
      emails: (map['emails'] as List?)
              ?.map((email) => ContactEmail.fromMap(email))
              .toList() ??
          [],
      addresses: (map['addresses'] as List?)
              ?.map((address) => ContactAddress.fromMap(address))
              .toList() ??
          [],
      events: (map['events'] as List?)
              ?.map((event) => ContactEvent.fromMap(event))
              .toList() ??
          [],
      websites: (map['websites'] as List?)
              ?.map((website) => ContactWebsite.fromMap(website))
              .toList() ??
          [],
      socialAccounts: (map['socialAccounts'] as List?)
              ?.map((account) => ContactSocialMedia.fromMap(account))
              .toList() ??
          [],
      relations: (map['relations'] as List?)
              ?.map((relation) => ContactRelation.fromMap(relation))
              .toList() ??
          [],
      groups: (map['groups'] as List?)
              ?.map((group) => ContactGroup.fromMap(group))
              .toList() ??
          [],
      company: map['company'],
      jobTitle: map['jobTitle'],
      department: map['department'],
      note: map['note'],
      photoBytes: map['photoBytes'],
      isStarred: map['isStarred'] ?? false,
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

class ContactAddress {
  final String? street;
  final String? city;
  final String? region; // state/province
  final String? postalCode;
  final String? country;
  final String? label; // home, work, etc.

  ContactAddress({
    this.street,
    this.city,
    this.region,
    this.postalCode,
    this.country,
    this.label,
  });

  factory ContactAddress.fromMap(Map<String, dynamic> map) {
    return ContactAddress(
      street: map['street'],
      city: map['city'],
      region: map['region'],
      postalCode: map['postalCode'],
      country: map['country'],
      label: map['label'],
    );
  }

  String get fullAddress {
    final parts = [
      if (street != null && street!.isNotEmpty) street,
      if (city != null && city!.isNotEmpty) city,
      if (region != null && region!.isNotEmpty) region,
      if (postalCode != null && postalCode!.isNotEmpty) postalCode,
      if (country != null && country!.isNotEmpty) country,
    ];
    return parts.join(', ');
  }
}

class ContactEvent {
  final DateTime? date;
  final String? label; // birthday, anniversary, etc.

  ContactEvent({
    this.date,
    this.label,
  });

  factory ContactEvent.fromMap(Map<String, dynamic> map) {
    return ContactEvent(
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
      label: map['label'],
    );
  }
}

class ContactWebsite {
  final String url;
  final String? label;

  ContactWebsite({
    required this.url,
    this.label,
  });

  factory ContactWebsite.fromMap(Map<String, dynamic> map) {
    return ContactWebsite(
      url: map['url'] ?? '',
      label: map['label'],
    );
  }
}

class ContactSocialMedia {
  final String username;
  final String? platform; // facebook, twitter, etc.

  ContactSocialMedia({
    required this.username,
    this.platform,
  });

  factory ContactSocialMedia.fromMap(Map<String, dynamic> map) {
    return ContactSocialMedia(
      username: map['username'] ?? '',
      platform: map['platform'],
    );
  }
}

class ContactRelation {
  final String name;
  final String? type; // spouse, child, parent, etc.

  ContactRelation({
    required this.name,
    this.type,
  });

  factory ContactRelation.fromMap(Map<String, dynamic> map) {
    return ContactRelation(
      name: map['name'] ?? '',
      type: map['type'],
    );
  }
}

class ContactGroup {
  final String name;
  final String? id;

  ContactGroup({
    required this.name,
    this.id,
  });

  factory ContactGroup.fromMap(Map<String, dynamic> map) {
    return ContactGroup(
      name: map['name'] ?? '',
      id: map['id'],
    );
  }
}
