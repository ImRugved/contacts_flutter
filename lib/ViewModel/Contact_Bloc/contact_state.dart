// lib/ViewModel/ContactBloc/contact_state.dart

import 'package:flutter/foundation.dart';
import '../../../Model/contact_model.dart';

abstract class ContactState {
  final bool searchByNumber;
  final bool isRefreshing;

  ContactState({this.searchByNumber = false, this.isRefreshing = false});
}

class ContactInitial extends ContactState {
  ContactInitial({super.searchByNumber, super.isRefreshing});
}

class ContactLoading extends ContactState {
  ContactLoading({super.searchByNumber, super.isRefreshing});
}

class ContactLoaded extends ContactState {
  final List<ContactModel> contacts;

  ContactLoaded({
    required this.contacts, 
    super.searchByNumber, 
    super.isRefreshing
  });
}

class ContactSearchResult extends ContactState {
  final List<ContactModel> searchResults;
  final String searchQuery;

  ContactSearchResult({
    required this.searchResults,
    required this.searchQuery,
    required super.searchByNumber,
    super.isRefreshing
  });
}

class ContactError extends ContactState {
  final String message;

  ContactError({required this.message, super.searchByNumber, super.isRefreshing});
}

class ContactPermissionDenied extends ContactState {
  final String message;

  ContactPermissionDenied({required this.message, super.searchByNumber, super.isRefreshing});
}
