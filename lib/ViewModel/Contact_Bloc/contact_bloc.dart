// lib/ViewModel/Contact_Bloc/contact_bloc.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
// Path provider import is needed for file operations in other methods
import '../../Model/contact_model.dart';
import 'contact_event.dart' as bloc_event;
import 'contact_state.dart';

class ContactBloc extends Bloc<bloc_event.ContactEvent, ContactState> {
  List<ContactModel> _allContacts = [];
  bool _searchByNumber = false;
  bool _initialLoadDone = false;

  ContactBloc() : super(ContactInitial()) {
    on<bloc_event.RequestContactPermission>((event, emit) async {
      // Only show loading on first load
      if (!_initialLoadDone) {
        emit(ContactLoading(searchByNumber: _searchByNumber));
      }
      
      try {
        final hasPermission = await fc.FlutterContacts.requestPermission();
        if (hasPermission) {
          add(bloc_event.LoadContacts(showLoading: !_initialLoadDone));
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

    on<bloc_event.LoadContacts>((event, emit) async {
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
    
    on<bloc_event.RefreshContacts>((event, emit) async {
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

    on<bloc_event.SearchContact>((event, emit) {
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

    on<bloc_event.ResetSearch>((event, emit) {
      emit(ContactLoaded(
          contacts: _allContacts, searchByNumber: _searchByNumber));
    });
    
    // Add contact handler
    on<bloc_event.AddContact>((event, emit) async {
      try {
        // First emit loading state
        emit(ContactLoading(searchByNumber: _searchByNumber));
        
        // Convert our ContactModel to flutter_contacts Contact
        final newContact = await _convertToFlutterContact(event.contact);
        
        // Save the contact to device
        await newContact.insert();
        
        // Reload contacts to get the updated list including the new contact
        await _loadContacts(forceReload: true);
        
        // Emit success state
        emit(ContactLoaded(
          contacts: _allContacts,
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: true,
            operation: 'add',
            message: 'Contact added successfully',
          ),
        ));
      } catch (e) {
        emit(ContactError(
          message: 'Error adding contact: ${e.toString()}',
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: false,
            operation: 'add',
            message: 'Failed to add contact: ${e.toString()}',
          ),
        ));
      }
    });
    
    // Update contact handler
    on<bloc_event.UpdateContact>((event, emit) async {
      try {
        // First emit loading state
        emit(ContactLoading(searchByNumber: _searchByNumber));
        
        // Get the existing contact from device with accounts information
        final existingContact = await fc.FlutterContacts.getContact(event.contact.id, withProperties: true, withPhoto: true, withAccounts: true);
        
        if (existingContact == null) {
          throw Exception('Contact not found');
        }
        
        // Update the contact with new values
        final updatedContact = await _updateFlutterContact(existingContact, event.contact);
        
        // Save the updated contact
        await updatedContact.update();
        
        // Reload contacts to get the updated list
        await _loadContacts(forceReload: true);
        
        // Emit success state
        emit(ContactLoaded(
          contacts: _allContacts,
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: true,
            operation: 'update',
            message: 'Contact updated successfully',
          ),
        ));
      } catch (e) {
        emit(ContactError(
          message: 'Error updating contact: ${e.toString()}',
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: false,
            operation: 'update',
            message: 'Failed to update contact: ${e.toString()}',
          ),
        ));
      }
    });
    
    // Delete contact handler
    on<bloc_event.DeleteContact>((event, emit) async {
      try {
        // First emit loading state
        emit(ContactLoading(searchByNumber: _searchByNumber));
        
        // Get the contact to delete
        final contactToDelete = await fc.FlutterContacts.getContact(event.contactId);
        
        if (contactToDelete == null) {
          throw Exception('Contact not found');
        }
        
        // Delete the contact
        await contactToDelete.delete();
        
        // Reload contacts to get the updated list
        await _loadContacts(forceReload: true);
        
        // Emit success state
        emit(ContactLoaded(
          contacts: _allContacts,
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: true,
            operation: 'delete',
            message: 'Contact deleted successfully',
          ),
        ));
      } catch (e) {
        emit(ContactError(
          message: 'Error deleting contact: ${e.toString()}',
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: false,
            operation: 'delete',
            message: 'Failed to delete contact: ${e.toString()}',
          ),
        ));
      }
    });
    
    // Import contacts handler
    on<bloc_event.ImportContacts>((event, emit) async {
      try {
        // First emit loading state
        emit(ContactLoading(searchByNumber: _searchByNumber));
        
        // Read the file content
        final fileContent = await File(event.filePath!).readAsString();
        int importedCount = 0;
        
        // Basic vCard parsing (simplified version)
        final vCards = fileContent.split('BEGIN:VCARD');
        for (var vCard in vCards) {
          if (vCard.trim().isEmpty) continue;
          
          // Create a new contact
          final contact = fc.Contact();
          
          // Extract name
          final nameMatch = RegExp(r'FN:(.*?)(\r?\n|$)').firstMatch(vCard);
          if (nameMatch != null && nameMatch.group(1) != null) {
            final name = nameMatch.group(1)!.trim();
            final nameParts = name.split(' ');
            if (nameParts.isNotEmpty) {
              contact.name.first = nameParts.first;
              if (nameParts.length > 1) {
                contact.name.last = nameParts.last;
              }
            }
          }
          
          // Extract phone numbers
          final phoneMatches = RegExp(r'TEL[^:]*:(.*?)(\r?\n|$)').allMatches(vCard);
          for (var match in phoneMatches) {
            if (match.group(1) != null) {
              contact.phones.add(fc.Phone(match.group(1)!.trim()));
            }
          }
          
          // Extract emails
          final emailMatches = RegExp(r'EMAIL[^:]*:(.*?)(\r?\n|$)').allMatches(vCard);
          for (var match in emailMatches) {
            if (match.group(1) != null) {
              contact.emails.add(fc.Email(match.group(1)!.trim()));
            }
          }
          
          // Insert the contact
          try {
            await contact.insert();
            importedCount++;
          } catch (e) {
            // Skip if there's an error with this contact
            print('Error importing contact: $e');
          }
        }
        
        // Reload contacts to get the updated list
        await _loadContacts(forceReload: true);
        
        // Emit success state
        emit(ContactLoaded(
          contacts: _allContacts,
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: true,
            operation: 'import',
            message: 'Imported $importedCount contacts successfully',
          ),
        ));
      } catch (e) {
        emit(ContactError(
          message: 'Error importing contacts: ${e.toString()}',
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: false,
            operation: 'import',
            message: 'Failed to import contacts: ${e.toString()}',
          ),
        ));
      }
    });
    
    // Export contact handler
    on<bloc_event.ExportContact>((event, emit) async {
      try {
        // Get the contact to export
        final contactToExport = await fc.FlutterContacts.getContact(event.contactId);
        
        if (contactToExport == null) {
          throw Exception('Contact not found');
        }
        
        String exportedData = '';
        String fileName = '';
        
        if (event.format == 'vcard') {
          // Export as vCard
          exportedData = _createVCard(contactToExport);
          fileName = '${contactToExport.displayName.replaceAll(' ', '_')}.vcf';
        }
        
        // Emit success state with the exported data
        emit(ContactLoaded(
          contacts: _allContacts,
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: true,
            operation: 'export',
            message: 'Contact exported successfully',
            data: {
              'data': exportedData,
              'fileName': fileName,
              'format': event.format,
            },
          ),
        ));
      } catch (e) {
        emit(ContactError(
          message: 'Error exporting contact: ${e.toString()}',
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: false,
            operation: 'export',
            message: 'Failed to export contact: ${e.toString()}',
          ),
        ));
      }
    });
    
    // Export all contacts handler
    on<bloc_event.ExportAllContacts>((event, emit) async {
      try {
        // Get all contacts with full details
        final allContacts = await fc.FlutterContacts.getContacts(
          withProperties: true,
          withPhoto: true,
        );
        
        String exportedData = '';
        String fileName = 'all_contacts.vcf';
        
        if (event.format == 'vcard') {
          // Export all contacts as a single vCard file
          final StringBuffer vCardBuffer = StringBuffer();
          for (var contact in allContacts) {
            // Simple vCard format
            vCardBuffer.writeln('BEGIN:VCARD');
            vCardBuffer.writeln('VERSION:3.0');
            vCardBuffer.writeln('FN:${contact.displayName}');
            vCardBuffer.writeln('N:${contact.name.last};${contact.name.first};;${contact.name.prefix};${contact.name.suffix}');
            
            // Add phones
            for (var phone in contact.phones) {
              vCardBuffer.writeln('TEL;TYPE=${phone.label.name.toUpperCase()}:${phone.number}');
            }
            
            // Add emails
            for (var email in contact.emails) {
              vCardBuffer.writeln('EMAIL;TYPE=${email.label.name.toUpperCase()}:${email.address}');
            }
            
            // Add addresses
            for (var address in contact.addresses) {
              vCardBuffer.writeln('ADR;TYPE=${address.label.name.toUpperCase()}:;;${address.address};${address.city};${address.state};${address.postalCode};${address.country}');
            }
            
            // Add organization
            if (contact.organizations.isNotEmpty) {
              final org = contact.organizations.first;
              if (org.company != null) {
                vCardBuffer.writeln('ORG:${org.company}');
              }
              if (org.title != null) {
                vCardBuffer.writeln('TITLE:${org.title}');
              }
            }
            
            vCardBuffer.writeln('END:VCARD');
          }
          exportedData = vCardBuffer.toString();
        }
        
        // Emit success state with the exported data
        emit(ContactLoaded(
          contacts: _allContacts,
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: true,
            operation: 'export_all',
            message: 'All contacts exported successfully',
            data: {
              'data': exportedData,
              'fileName': fileName,
              'format': event.format,
              'count': allContacts.length,
            },
          ),
        ));
      } catch (e) {
        emit(ContactError(
          message: 'Error exporting all contacts: ${e.toString()}',
          searchByNumber: _searchByNumber,
          operationStatus: OperationStatus(
            isSuccess: false,
            operation: 'export_all',
            message: 'Failed to export all contacts: ${e.toString()}',
          ),
        ));
      }
    });
  }

  Future<void> _loadContacts({bool forceReload = false}) async {
    if (await fc.FlutterContacts.requestPermission()) {
      // Get all contacts (fully fetched)
      final contacts = await fc.FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: true,
      );

      _allContacts = contacts.map((contact) {
        return ContactModel(
          id: contact.id,
          displayName: contact.displayName,
          firstName: contact.name.first,
          lastName: contact.name.last,
          prefix: contact.name.prefix,
          suffix: contact.name.suffix,
          phones: contact.phones
              .map((phone) => PhoneNumber(
                    number: phone.number,
                    label: _getLabelFromPhoneLabel(phone.label),
              ))
              .toList(),
          emails: contact.emails
              .map((email) => ContactEmail(
                    address: email.address,
                    label: _getLabelFromEmailLabel(email.label),
              ))
              .toList(),
          addresses: contact.addresses
              .map((address) => ContactAddress(
                street: address.address,
                city: address.city,
                region: address.state,
                postalCode: address.postalCode,
                country: address.country,
                label: _getLabelFromAddressLabel(address.label),
              ))
              .toList(),
          // Add events if available in the package
          events: [],
          websites: contact.websites
              .map((website) => ContactWebsite(
                    url: website.url,
                    label: _getLabelFromWebsiteLabel(website.label),
              ))
              .toList(),
          company: contact.organizations.isNotEmpty ? contact.organizations.first.company : null,
          jobTitle: contact.organizations.isNotEmpty ? contact.organizations.first.title : null,
          department: contact.organizations.isNotEmpty ? contact.organizations.first.department : null,
          note: contact.notes.isNotEmpty ? contact.notes.first.note : null,
          photoBytes: contact.photo != null
              ? base64Encode(contact.photo!)
              : null,
          isStarred: contact.isStarred,
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
      // Search in first name, last name, and display name
      final firstName = (contact.firstName ?? '').toLowerCase();
      final lastName = (contact.lastName ?? '').toLowerCase();
      final displayName = contact.displayName.toLowerCase();
      
      return firstName.contains(lowercaseQuery) || 
             lastName.contains(lowercaseQuery) || 
             displayName.contains(lowercaseQuery);
    }).toList();
  }

  List<ContactModel> _searchContactsByNumber(
      List<ContactModel> contacts, String query) {
    if (query.isEmpty) return contacts;

    return contacts.where((contact) {
      return contact.phones.any((phone) => phone.number.contains(query));
    }).toList();
  }
  
  // Helper method to convert our ContactModel to flutter_contacts Contact
  Future<fc.Contact> _convertToFlutterContact(ContactModel model) async {
    // Create a new Contact
    final contact = fc.Contact();
    
    // Set name
    contact.name.first = model.firstName ?? '';
    contact.name.last = model.lastName ?? '';
    contact.name.prefix = model.prefix ?? '';
    contact.name.suffix = model.suffix ?? '';
    
    // Set display name - this is important for the contact to show up properly
    String displayName = '';
    if ((model.firstName ?? '').isNotEmpty) {
      displayName += model.firstName!;
    }
    if ((model.lastName ?? '').isNotEmpty) {
      if (displayName.isNotEmpty) displayName += ' ';
      displayName += model.lastName!;
    }
    contact.displayName = displayName.isNotEmpty ? displayName : 'New Contact';
    
    // Set phones
    contact.phones = model.phones.map((phone) {
      return fc.Phone(phone.number, label: _getPhoneLabelFromString(phone.label));
    }).toList();
    
    // Set emails
    contact.emails = model.emails.map((email) {
      return fc.Email(email.address, label: _getEmailLabelFromString(email.label));
    }).toList();
    
    // Set addresses
    contact.addresses = model.addresses.map((address) {
      return fc.Address(
        address.street ?? '',
        label: _getAddressLabelFromString(address.label),
        street: address.street ?? '',
        city: address.city ?? '',
        state: address.region ?? '',
        postalCode: address.postalCode ?? '',
        country: address.country ?? '',
      );
    }).toList();
    
    // Set websites
    contact.websites = model.websites.map((website) {
      return fc.Website(website.url, label: _getWebsiteLabelFromString(website.label));
    }).toList();
    
    // Set organization
    if (model.company != null || model.jobTitle != null) {
      contact.organizations = [
        fc.Organization(
          company: model.company ?? '',
          title: model.jobTitle ?? '',
          department: model.department ?? '',
        )
      ];
    }
    
    // Set notes
    if (model.note != null && model.note!.isNotEmpty) {
      contact.notes = [fc.Note(model.note!)];
    }
    
    // Set photo if available
    if (model.photoBytes != null) {
      try {
        contact.photo = base64Decode(model.photoBytes!);
      } catch (e) {
        // Ignore photo errors
      }
    }
    
    return contact;
  }
  
  // Helper method to update an existing flutter_contacts Contact with our ContactModel data
  Future<fc.Contact> _updateFlutterContact(fc.Contact existingContact, ContactModel model) async {
    // Update name
    if (model.firstName != null) existingContact.name.first = model.firstName!;
    if (model.lastName != null) existingContact.name.last = model.lastName!;
    if (model.prefix != null) existingContact.name.prefix = model.prefix!;
    if (model.suffix != null) existingContact.name.suffix = model.suffix!;
    
    // Update phones (replace all)
    if (model.phones.isNotEmpty) {
      existingContact.phones = model.phones.map((phone) {
        return fc.Phone(phone.number, label: _getPhoneLabelFromString(phone.label));
      }).toList();
    }
    
    // Update emails (replace all)
    if (model.emails.isNotEmpty) {
      existingContact.emails = model.emails.map((email) {
        return fc.Email(email.address, label: _getEmailLabelFromString(email.label));
      }).toList();
    }
    
    // Update addresses (replace all)
    if (model.addresses.isNotEmpty) {
      existingContact.addresses = model.addresses.map((address) {
        return fc.Address(
          address.street ?? '',
          label: _getAddressLabelFromString(address.label),
          street: address.street ?? '',
          city: address.city ?? '',
          state: address.region ?? '',
          postalCode: address.postalCode ?? '',
          country: address.country ?? '',
        );
      }).toList();
    }
    
    // Update websites (replace all)
    if (model.websites.isNotEmpty) {
      existingContact.websites = model.websites.map((website) {
        return fc.Website(website.url, label: _getWebsiteLabelFromString(website.label));
      }).toList();
    }
    
    // Update organization
    if (model.company != null || model.jobTitle != null) {
      existingContact.organizations = [
        fc.Organization(
          company: model.company ?? '',
          title: model.jobTitle ?? '',
          department: model.department ?? '',
        )
      ];
    }
    
    // Update notes
    if (model.note != null && model.note!.isNotEmpty) {
      existingContact.notes = [fc.Note(model.note!)];
    }
    
    // Update photo if available
    if (model.photoBytes != null) {
      try {
        existingContact.photo = base64Decode(model.photoBytes!);
      } catch (e) {
        // Ignore photo errors
      }
    }
    
    return existingContact;
  }
  
  // Helper method to create a vCard string from a Contact
  String _createVCard(fc.Contact contact) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    
    // Add name
    buffer.writeln('N:${contact.name.last};${contact.name.first};;${contact.name.prefix};${contact.name.suffix}');
    buffer.writeln('FN:${contact.displayName}');
    
    // Add phones
    for (var phone in contact.phones) {
      String type = 'TEL';
      switch (phone.label) {
        case fc.PhoneLabel.mobile:
          type = 'TEL;TYPE=CELL';
          break;
        case fc.PhoneLabel.home:
          type = 'TEL;TYPE=HOME';
          break;
        case fc.PhoneLabel.work:
          type = 'TEL;TYPE=WORK';
          break;
        case fc.PhoneLabel.main:
          type = 'TEL;TYPE=MAIN';
          break;
        default:
          type = 'TEL;TYPE=OTHER';
      }
      buffer.writeln('$type:${phone.number}');
    }
    
    // Add emails
    for (var email in contact.emails) {
      String type = 'EMAIL';
      switch (email.label) {
        case fc.EmailLabel.home:
          type = 'EMAIL;TYPE=HOME';
          break;
        case fc.EmailLabel.work:
          type = 'EMAIL;TYPE=WORK';
          break;
        default:
          type = 'EMAIL;TYPE=OTHER';
      }
      buffer.writeln('$type:${email.address}');
    }
    
    // Add addresses
    for (var address in contact.addresses) {
      String type = 'ADR';
      switch (address.label) {
        case fc.AddressLabel.home:
          type = 'ADR;TYPE=HOME';
          break;
        case fc.AddressLabel.work:
          type = 'ADR;TYPE=WORK';
          break;
        default:
          type = 'ADR;TYPE=OTHER';
      }
      buffer.writeln('$type:;;${address.address};${address.city};${address.state};${address.postalCode};${address.country}');
    }
    
    // Add organization
    if (contact.organizations.isNotEmpty) {
      final org = contact.organizations.first;
      if (org.company != null) {
        buffer.writeln('ORG:${org.company}');
      }
      if (org.title != null) {
        buffer.writeln('TITLE:${org.title}');
      }
    }
    
    // Add notes
    if (contact.notes.isNotEmpty) {
      buffer.writeln('NOTE:${contact.notes.first.note}');
    }
    
    // Add photo if available
    if (contact.photo != null && contact.photo!.isNotEmpty) {
      final base64Photo = base64Encode(contact.photo!);
      buffer.writeln('PHOTO;ENCODING=BASE64;TYPE=JPEG:$base64Photo');
    }
    
    // Add timestamp
    final now = DateTime.now();
    buffer.writeln('REV:${now.toIso8601String().replaceAll('-', '').replaceAll(':', '')}');
    
    buffer.writeln('END:VCARD');
    return buffer.toString();
  }
  
  // Helper method to convert string labels to flutter_contacts label enums
  String _getLabelFromPhoneLabel(fc.PhoneLabel label) {
    switch (label) {
      case fc.PhoneLabel.home:
        return 'home';
      case fc.PhoneLabel.work:
        return 'work';
      case fc.PhoneLabel.mobile:
        return 'mobile';
      case fc.PhoneLabel.main:
        return 'main';
      default:
        return 'other';
    }
  }
  
  String _getLabelFromEmailLabel(fc.EmailLabel label) {
    switch (label) {
      case fc.EmailLabel.home:
        return 'home';
      case fc.EmailLabel.work:
        return 'work';
      default:
        return 'other';
    }
  }
  
  String _getLabelFromAddressLabel(fc.AddressLabel label) {
    switch (label) {
      case fc.AddressLabel.home:
        return 'home';
      case fc.AddressLabel.work:
        return 'work';
      default:
        return 'other';
    }
  }
  
  String _getLabelFromWebsiteLabel(fc.WebsiteLabel label) {
    switch (label) {
      case fc.WebsiteLabel.home:
        return 'home';
      case fc.WebsiteLabel.work:
        return 'work';
      default:
        return 'other';
    }
  }
  
  // Reverse conversion methods
  fc.PhoneLabel _getPhoneLabelFromString(String? label) {
    if (label == null) return fc.PhoneLabel.other;
    
    switch (label.toLowerCase()) {
      case 'home':
        return fc.PhoneLabel.home;
      case 'work':
        return fc.PhoneLabel.work;
      case 'mobile':
        return fc.PhoneLabel.mobile;
      case 'main':
        return fc.PhoneLabel.main;
      default:
        return fc.PhoneLabel.other;
    }
  }
  
  fc.EmailLabel _getEmailLabelFromString(String? label) {
    if (label == null) return fc.EmailLabel.other;
    
    switch (label.toLowerCase()) {
      case 'home':
        return fc.EmailLabel.home;
      case 'work':
        return fc.EmailLabel.work;
      default:
        return fc.EmailLabel.other;
    }
  }
  
  fc.AddressLabel _getAddressLabelFromString(String? label) {
    if (label == null) return fc.AddressLabel.other;
    
    switch (label.toLowerCase()) {
      case 'home':
        return fc.AddressLabel.home;
      case 'work':
        return fc.AddressLabel.work;
      default:
        return fc.AddressLabel.other;
    }
  }
  
  fc.WebsiteLabel _getWebsiteLabelFromString(String? label) {
    if (label == null) return fc.WebsiteLabel.other;
    
    switch (label.toLowerCase()) {
      case 'home':
        return fc.WebsiteLabel.home;
      case 'work':
        return fc.WebsiteLabel.work;
      default:
        return fc.WebsiteLabel.other;
    }
  }
}
