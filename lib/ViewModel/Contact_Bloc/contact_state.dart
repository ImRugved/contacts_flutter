// lib/ViewModel/ContactBloc/contact_state.dart

import 'package:flutter/foundation.dart';
import '../../../Model/contact_model.dart';

abstract class ContactState {
  final bool searchByNumber;
  final bool isRefreshing;
  final OperationStatus? operationStatus;

  ContactState({
    this.searchByNumber = false, 
    this.isRefreshing = false,
    this.operationStatus,
  });
}

class OperationStatus {
  final bool isSuccess;
  final String operation; // 'add', 'update', 'delete', 'import', 'export'
  final String message;
  final dynamic data; // Additional data related to the operation

  OperationStatus({
    required this.isSuccess,
    required this.operation,
    required this.message,
    this.data,
  });
}

class ContactInitial extends ContactState {
  ContactInitial({super.searchByNumber, super.isRefreshing, super.operationStatus});
}

class ContactLoading extends ContactState {
  ContactLoading({super.searchByNumber, super.isRefreshing, super.operationStatus});
}

class ContactLoaded extends ContactState {
  final List<ContactModel> contacts;

  ContactLoaded({
    required this.contacts, 
    super.searchByNumber, 
    super.isRefreshing,
    super.operationStatus,
  });
}

class ContactSearchResult extends ContactState {
  final List<ContactModel> searchResults;
  final String searchQuery;

  ContactSearchResult({
    required this.searchResults,
    required this.searchQuery,
    required super.searchByNumber,
    super.isRefreshing,
    super.operationStatus,
  });
}

class ContactError extends ContactState {
  final String message;

  ContactError({
    required this.message, 
    super.searchByNumber, 
    super.isRefreshing,
    super.operationStatus,
  });
}

class ContactPermissionDenied extends ContactState {
  final String message;

  ContactPermissionDenied({
    required this.message, 
    super.searchByNumber, 
    super.isRefreshing,
    super.operationStatus,
  });
}
