// lib/ViewModel/ContactBloc/contact_event.dart

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
