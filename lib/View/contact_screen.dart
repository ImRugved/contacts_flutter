// lib/View/contact_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:contact_flutter/ViewModel/Contact_Bloc/contact_bloc.dart';
import 'package:contact_flutter/ViewModel/Contact_Bloc/contact_event.dart';
import 'package:contact_flutter/ViewModel/Contact_Bloc/contact_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

import '../Model/contact_model.dart';
import 'contact_detail_screen.dart';
import 'contact_form_screen.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({Key? key}) : super(key: key);

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    // Register as an observer to detect app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Request permission and load contacts when screen initializes
    context.read<ContactBloc>().add(RequestContactPermission());

    // Add listener to update UI when text changes
    _searchController.addListener(() {
      setState(() {
        _showClearButton = _searchController.text.isNotEmpty;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app is resumed, unfocus the search field to prevent keyboard from showing
    if (state == AppLifecycleState.resumed) {
      _searchFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    // Remove observer when disposing
    WidgetsBinding.instance.removeObserver(this);
    
    // Clean up controllers and focus nodes
    _searchController.removeListener(() {});
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      context.read<ContactBloc>().add(ResetSearch());
    } else {
      // Search by both name and number simultaneously
      context.read<ContactBloc>().add(SearchContact(query: query));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactBloc, ContactState>(
      listener: (context, state) {
        if (state is ContactLoaded && state.operationStatus != null) {
          final status = state.operationStatus!;
          if (status.isSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(status.message),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else if (state is ContactError && state.operationStatus != null) {
          final status = state.operationStatus!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(status.message),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Contacts'),
          actions: [
            // Only keep the refresh button in app bar
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                context.read<ContactBloc>().add(RefreshContacts());
              },
              tooltip: 'Refresh contacts',
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleMenuAction(context, value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: Text('Import Contacts'),
                ),
                const PopupMenuItem(
                  value: 'export_all',
                  child: Text('Export All Contacts'),
                ),
              ],
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToAddContact(context),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  labelText: 'Search by name or number',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  hintText: 'Enter name or phone number',
                  suffixIcon: _showClearButton
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            context.read<ContactBloc>().add(ResetSearch());
                            // Clear focus when clearing search
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                ),
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchFocusNode.unfocus(),
              ),
            ),
            Expanded(
              child: BlocBuilder<ContactBloc, ContactState>(
                builder: (context, state) {
                  if (state is ContactLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (state is ContactLoaded) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        // Create a completer to track when refresh is done
                        final completer = Completer<void>();

                        // Listen for state changes to know when refresh is complete
                        final subscription =
                            BlocProvider.of<ContactBloc>(context)
                                .stream
                                .listen((newState) {
                          if (newState is ContactLoaded &&
                              !newState.isRefreshing) {
                            if (!completer.isCompleted) {
                              completer.complete();
                            }
                          } else if (newState is ContactError) {
                            if (!completer.isCompleted) {
                              completer.completeError(newState.message);
                            }
                          }
                        });

                        // Trigger the refresh
                        context.read<ContactBloc>().add(RefreshContacts());

                        // Wait for refresh to complete or timeout after 5 seconds
                        try {
                          await completer.future
                              .timeout(const Duration(seconds: 5));
                        } catch (e) {
                          // Handle timeout or error
                        } finally {
                          subscription.cancel();
                        }
                      },
                      child: Stack(
                        children: [
                          _buildContactList(state.contacts),
                          if (state.isRefreshing)
                            const Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: LinearProgressIndicator(),
                            ),
                        ],
                      ),
                    );
                  } else if (state is ContactSearchResult) {
                    return Stack(
                      children: [
                        _buildContactList(state.searchResults),
                        if (state.isRefreshing)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(),
                          ),
                      ],
                    );
                  } else if (state is ContactError) {
                    return Center(
                      child: Text(
                        state.message,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  } else if (state is ContactPermissionDenied) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(state.message),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              context
                                  .read<ContactBloc>()
                                  .add(RequestContactPermission());
                            },
                            child: const Text('Request Permission Again'),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const Center(
                      child: Text('No contacts found'),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList(List<ContactModel> contacts) {
    if (contacts.isEmpty) {
      // Return a scrollable widget even when empty for RefreshIndicator to work
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 100),
              child: Text('No contacts found'),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      // Enable physics for pull to refresh
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _buildContactItem(context, contact);
      },
    );
  }

  Widget _buildContactItem(BuildContext context, ContactModel contact) {
    return Dismissible(
      key: Key(contact.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Contact'),
              content: Text(
                  'Are you sure you want to delete ${contact.displayName}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        context.read<ContactBloc>().add(DeleteContact(contactId: contact.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${contact.displayName} deleted')),
        );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          backgroundImage: _getContactImage(contact),
          child: _getContactInitial(contact),
        ),
        title: Text(contact.displayName),
        subtitle: contact.phones.isNotEmpty
            ? Text(contact.phones.first.number)
            : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactDetailScreen(contact: contact),
            ),
          );
        },
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _navigateToEditContact(context, contact),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) async {
    switch (action) {
      case 'import':
        await _importContacts(context);
        break;
      case 'export_all':
        await _exportAllContacts(context);
        break;
    }
  }

  Future<void> _importContacts(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vcf'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        context.read<ContactBloc>().add(ImportContacts(
              source: 'vcard',
              filePath: filePath,
            ));

        // Show a snackbar to indicate import has started
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Importing contacts...')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing contacts: $e')),
      );
    }
  }

  Future<void> _exportAllContacts(BuildContext context) async {
    try {
      // Show a snackbar to indicate export has started
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exporting contacts...')),
      );

      // Get the ContactBloc
      final contactBloc = context.read<ContactBloc>();

      // Create a subscription variable first to avoid reference before declaration
      late StreamSubscription<ContactState> subscription;

      // Listen for the export result
      subscription = contactBloc.stream.listen((state) async {
        if (state is ContactLoaded &&
            state.operationStatus != null &&
            state.operationStatus!.operation == 'export_all' &&
            state.operationStatus!.isSuccess) {
          // Unsubscribe to avoid multiple calls
          subscription.cancel();

          try {
            // Get the exported data
            final exportData = state.operationStatus!.data!;
            final vCardData = exportData['data'] as String;
            final fileName = exportData['fileName'] as String;
            final count = exportData['count'] as int;

            // Create a temporary file to share
            final directory = await getTemporaryDirectory();
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsString(vCardData);

            // Show success message with file path
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Exported $count contacts successfully'),
                    const SizedBox(height: 4),
                    Text(
                      'Saved to: $filePath',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 5),
              ),
            );

            // Share the file
            if (await file.exists()) {
              // Clear any previous snackbars
              ScaffoldMessenger.of(context).hideCurrentSnackBar();

              // Share the file
              final box = context.findRenderObject() as RenderBox?;
              await SharePlus.instance.share(
                ShareParams(
                  text: 'Exported contacts ($count)',
                  files: [XFile(filePath)],
                  subject: 'Contact Information',
                  sharePositionOrigin: box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null,
                ),
              );
            }
          } catch (shareError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error sharing contacts: $shareError')),
            );
            print('Share error: $shareError');
          }
        } else if (state is ContactError &&
            state.operationStatus != null &&
            state.operationStatus!.operation == 'export_all') {
          // Unsubscribe on error
          subscription.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.operationStatus!.message)),
          );
        }
      });

      // Add the export event after setting up the listener
      contactBloc.add(ExportAllContacts(format: 'vcard'));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting contacts: $e')),
      );
    }
  }

  void _navigateToAddContact(BuildContext context) {
    // Clear focus before navigating
    _searchFocusNode.unfocus();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: BlocProvider.of<ContactBloc>(context),
          child: const ContactFormScreen(),
        ),
      ),
    );
  }

  void _navigateToEditContact(BuildContext context, ContactModel contact) {
    // Clear focus before navigating to edit screen
    _searchFocusNode.unfocus();
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: BlocProvider.of<ContactBloc>(context),
          child: ContactFormScreen(
            contact: contact,
            isEditing: true,
          ),
        ),
      ),
    );
  }

  // Safely get contact image with error handling
  ImageProvider? _getContactImage(ContactModel contact) {
    if (contact.photoBytes == null) return null;

    try {
      return MemoryImage(base64Decode(contact.photoBytes!));
    } catch (e) {
      // If there's an error decoding the image, return null
      return null;
    }
  }

  // Get contact initial for avatar fallback
  Widget? _getContactInitial(ContactModel contact) {
    // Only show initial if there's no photo or if photo loading failed
    if (contact.photoBytes == null || _getContactImage(contact) == null) {
      return Text(
        contact.displayName.isNotEmpty
            ? contact.displayName[0].toUpperCase()
            : '?',
        style:
            const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
      );
    }
    return null;
  }
}
