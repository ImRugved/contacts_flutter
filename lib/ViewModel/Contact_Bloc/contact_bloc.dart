// lib/ViewModel/ContactBloc/contact_bloc.dart

import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'contact_event.dart';
import 'contact_state.dart';
import '../../../Model/contact_model.dart';

class ContactBloc extends Bloc<ContactEvent, ContactState> {
  List<ContactModel> _allContacts = [];
  bool _searchByNumber = false;
  bool _initialLoadDone = false;

  ContactBloc() : super(ContactInitial()) {
    on<RequestContactPermission>((event, emit) async {
      // Only show loading on first load
      if (!_initialLoadDone) {
        emit(ContactLoading(searchByNumber: _searchByNumber));
      }
      
      try {
        final hasPermission = await FlutterContacts.requestPermission();
        if (hasPermission) {
          add(LoadContacts(showLoading: !_initialLoadDone));
        } else {
          emit(ContactPermissionDenied(
              message: 'Permission denied to access contacts',
              searchByNumber: _searchByNumber));
        }
      } catch (e) {
        emit(ContactError(
            message: 'Error requesting permission: ${e.toString()}',
            searchByNumber: _searchByNumber));
      }
    });

    on<LoadContacts>((event, emit) async {
      // Only show loading state if explicitly requested or on first load
      if (event.showLoading) {
        emit(ContactLoading(searchByNumber: _searchByNumber));
      } else if (event.isRefreshing) {
        // Show refreshing indicator if we're refreshing
        emit(ContactLoaded(
            contacts: _allContacts,
            searchByNumber: _searchByNumber,
            isRefreshing: true));
      }
      
      try {
        // Pass forceReload parameter to ensure contacts are reloaded when refreshing
        await _loadContacts(forceReload: event.isRefreshing);
        _initialLoadDone = true;
        emit(ContactLoaded(
            contacts: _allContacts, 
            searchByNumber: _searchByNumber,
            isRefreshing: false));
      } catch (e) {
        emit(ContactError(
            message: 'Error loading contacts: ${e.toString()}',
            searchByNumber: _searchByNumber));
      }
    });
    
    on<RefreshContacts>((event, emit) async {
      // Don't show full loading screen, just set refreshing flag
      if (_allContacts.isNotEmpty) {
        emit(ContactLoaded(
            contacts: _allContacts,
            searchByNumber: _searchByNumber,
            isRefreshing: true));
      }
      
      // Force reload contacts from device
      try {
        await _loadContacts(forceReload: true);
        emit(ContactLoaded(
            contacts: _allContacts, 
            searchByNumber: _searchByNumber,
            isRefreshing: false));
      } catch (e) {
        emit(ContactError(
            message: 'Error refreshing contacts: ${e.toString()}',
            searchByNumber: _searchByNumber));
      }
    });

    on<SearchContact>((event, emit) {
      emit(ContactLoading(searchByNumber: _searchByNumber));
      try {
        // Search by both name and number simultaneously
        final nameResults = _searchContactsByName(_allContacts, event.query);
        final numberResults = _searchContactsByNumber(_allContacts, event.query);
        
        // Combine results and remove duplicates
        final Set<String> addedIds = {};
        final List<ContactModel> combinedResults = [];
        
        for (var contact in [...nameResults, ...numberResults]) {
          if (!addedIds.contains(contact.id)) {
            addedIds.add(contact.id);
            combinedResults.add(contact);
          }
        }
        
        emit(ContactSearchResult(
            searchResults: combinedResults,
            searchQuery: event.query,
            searchByNumber: _searchByNumber));
      } catch (e) {
        emit(ContactError(
            message: 'Error searching contacts: ${e.toString()}',
            searchByNumber: _searchByNumber));
      }
    });

    // Remove ToggleSearchType handler since we now search by both simultaneously

    on<ResetSearch>((event, emit) {
      emit(ContactLoaded(
          contacts: _allContacts, searchByNumber: _searchByNumber));
    });
  }

  Future<void> _loadContacts({bool forceReload = false}) async {
    if (await FlutterContacts.requestPermission()) {
      // Get all contacts (fully fetched)
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      _allContacts = contacts.map((contact) {
        return ContactModel(
          id: contact.id,
          displayName: contact.displayName,
          phones: contact.phones
              .map((phone) => PhoneNumber(
                    number: phone.number,
                    label: phone.label.name,
                  ))
              .toList(),
          emails: contact.emails
              .map((email) => ContactEmail(
                    address: email.address,
                    label: email.label.name,
                  ))
              .toList(),
          photoBytes: contact.photo != null
              ? base64Encode(contact.photo!)
              : null,
        );
      }).toList();
    } else {
      throw Exception('Permission denied');
    }
  }

  List<ContactModel> _searchContactsByName(
      List<ContactModel> contacts, String query) {
    if (query.isEmpty) return contacts;

    final lowercaseQuery = query.toLowerCase();
    return contacts.where((contact) {
      return contact.displayName.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  List<ContactModel> _searchContactsByNumber(
      List<ContactModel> contacts, String query) {
    if (query.isEmpty) return contacts;

    return contacts.where((contact) {
      return contact.phones.any((phone) => phone.number.contains(query));
    }).toList();
  }
}
