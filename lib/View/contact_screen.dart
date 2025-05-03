// lib/View/contact_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:contact_flutter/ViewModel/Contact_Bloc/contact_bloc.dart';
import 'package:contact_flutter/ViewModel/Contact_Bloc/contact_event.dart';
import 'package:contact_flutter/ViewModel/Contact_Bloc/contact_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Model/contact_model.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({Key? key}) : super(key: key);

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
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
  void dispose() {
    _searchController.removeListener(() {});
    _searchController.dispose();
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
    return Scaffold(
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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
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
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
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
                      final subscription = BlocProvider.of<ContactBloc>(context).stream.listen((newState) {
                        if (newState is ContactLoaded && !newState.isRefreshing) {
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
                        await completer.future.timeout(const Duration(seconds: 5));
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
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: contact.photoBytes != null
                ? MemoryImage(base64Decode(contact.photoBytes!))
                : null,
            child: contact.photoBytes == null
                ? Text(contact.displayName.isNotEmpty
                    ? contact.displayName[0].toUpperCase()
                    : '?')
                : null,
          ),
          title: Text(contact.displayName),
          subtitle: contact.phones.isNotEmpty
              ? Text(contact.phones.first.number)
              : const Text('No phone number'),
          onTap: () {
            // Handle contact selection
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected ${contact.displayName}'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}
