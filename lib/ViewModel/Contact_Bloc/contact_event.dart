// lib/ViewModel/ContactBloc/contact_event.dart

import '../../Model/contact_model.dart';

abstract class ContactEvent {}

class LoadContacts extends ContactEvent {
  final bool showLoading;
  final bool isRefreshing;
  
  LoadContacts({this.showLoading = true, this.isRefreshing = false});
}

class RefreshContacts extends ContactEvent {}

class RequestContactPermission extends ContactEvent {}

class SearchContact extends ContactEvent {
  final String query;

  SearchContact({required this.query});
}

class ToggleSearchType extends ContactEvent {
  final String currentQuery;

  ToggleSearchType({required this.currentQuery});
}

class ResetSearch extends ContactEvent {}

// New events for contact operations
class AddContact extends ContactEvent {
  final ContactModel contact;
  
  AddContact({required this.contact});
}

class UpdateContact extends ContactEvent {
  final ContactModel contact;
  
  UpdateContact({required this.contact});
}

class DeleteContact extends ContactEvent {
  final String contactId;
  
  DeleteContact({required this.contactId});
}

class ImportContacts extends ContactEvent {
  final String source; // 'device', 'vcard', etc.
  final String? filePath; // For vCard import
  
  ImportContacts({required this.source, this.filePath});
}

class ExportContact extends ContactEvent {
  final String contactId;
  final String format; // 'vcard', etc.
  
  ExportContact({required this.contactId, required this.format});
}

class ExportAllContacts extends ContactEvent {
  final String format; // 'vcard', etc.
  
  ExportAllContacts({required this.format});
}
