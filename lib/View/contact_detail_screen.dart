// lib/View/contact_detail_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:contact_flutter/Model/contact_model.dart';
import 'package:contact_flutter/ViewModel/Contact_Bloc/contact_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:url_launcher/url_launcher.dart';
import 'contact_form_screen.dart';

class ContactDetailScreen extends StatelessWidget {
  final ContactModel contact;

  const ContactDetailScreen({Key? key, required this.contact})
      : super(key: key);

  void _navigateToEditContact(BuildContext context) {
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

  Future<void> _shareContact(BuildContext context) async {
    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparing contact for sharing...')),
      );

      // Create a vCard string
      String vCardString = 'BEGIN:VCARD\n';
      vCardString += 'VERSION:3.0\n';
      vCardString += 'FN:${contact.displayName}\n';
      vCardString +=
          'N:${contact.lastName ?? ''};${contact.firstName ?? ''};\n';

      // Add phone numbers
      for (var phone in contact.phones) {
        vCardString +=
            'TEL;TYPE=${phone.label?.toUpperCase() ?? 'CELL'}:${phone.number}\n';
      }

      // Add emails
      for (var email in contact.emails) {
        vCardString +=
            'EMAIL;TYPE=${email.label?.toUpperCase() ?? 'HOME'}:${email.address}\n';
      }

      // Add addresses
      for (var address in contact.addresses) {
        vCardString += 'ADR;TYPE=${address.label?.toUpperCase() ?? 'HOME'}:;;'
            '${address.street ?? ''}'
            ';${address.city ?? ''}'
            ';${address.region ?? ''}'
            ';${address.postalCode ?? ''}'
            ';${address.country ?? ''}\n';
      }

      // Add company info if available
      if (contact.company != null) {
        vCardString += 'ORG:${contact.company}\n';
      }
      if (contact.jobTitle != null) {
        vCardString += 'TITLE:${contact.jobTitle}\n';
      }

      // End vCard
      vCardString += 'END:VCARD\n';

      // Create a temporary file to share
      final directory = await getTemporaryDirectory();
      final fileName = '${contact.displayName.replaceAll(' ', '_')}.vcf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsString(vCardString);

      // Share the vCard file using share_plus
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sharing contact...')),
      );

      // Make sure the file exists before sharing
      if (await File(filePath).exists()) {
        print('File exists at: $filePath');

        // Clear any previous snackbars
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // Use the new SharePlus API
        try {
          final box = context.findRenderObject() as RenderBox?;

          await SharePlus.instance.share(
            ShareParams(
              text: 'Contact information for ${contact.displayName}',
              files: [XFile(filePath)],
              subject: 'Contact information',
              sharePositionOrigin: box != null
                  ? box.localToGlobal(Offset.zero) & box.size
                  : null,
            ),
          );
          print('Contact share initiated');
        } catch (shareError) {
          // If sharing fails, at least tell the user where the file is
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Contact exported to $filePath')),
          );
          print('Share error: $shareError');
        }
      } else {
        // File doesn't exist
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Contact file not found')),
        );
        print('File does not exist at: $filePath');
      }
    } catch (e) {
      // Hide the loading indicator if showing
      ScaffoldMessenger.of(context).clearSnackBars();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(contact.displayName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEditContact(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareContact(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact header with photo
            _buildContactHeader(context),

            // Basic information
            if (contact.company != null || contact.jobTitle != null)
              _buildSectionCard(
                context,
                'Work',
                Icons.business,
                [
                  if (contact.jobTitle != null)
                    _buildInfoRow('Title', contact.jobTitle!),
                  if (contact.company != null)
                    _buildInfoRow('Company', contact.company!),
                  if (contact.department != null)
                    _buildInfoRow('Department', contact.department!),
                ],
              ),

            // Phone numbers
            if (contact.phones.isNotEmpty)
              _buildSectionCard(
                context,
                'Phone',
                Icons.phone,
                contact.phones.map((phone) {
                  return _buildActionRow(
                    phone.label ?? 'Phone',
                    phone.number,
                    [
                      IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () => _makePhoneCall(phone.number),
                      ),
                      IconButton(
                        icon: const Icon(Icons.message, color: Colors.blue),
                        onPressed: () => _sendSMS(phone.number),
                      ),
                    ],
                  );
                }).toList(),
              ),

            // Email addresses
            if (contact.emails.isNotEmpty)
              _buildSectionCard(
                context,
                'Email',
                Icons.email,
                contact.emails.map((email) {
                  return _buildActionRow(
                    email.label ?? 'Email',
                    email.address,
                    [
                      IconButton(
                        icon: const Icon(Icons.email, color: Colors.red),
                        onPressed: () => _sendEmail(email.address),
                      ),
                    ],
                  );
                }).toList(),
              ),

            // Addresses
            if (contact.addresses.isNotEmpty)
              _buildSectionCard(
                context,
                'Address',
                Icons.location_on,
                contact.addresses.map((address) {
                  return _buildActionRow(
                    address.label ?? 'Address',
                    address.fullAddress,
                    [
                      IconButton(
                        icon: const Icon(Icons.map, color: Colors.green),
                        onPressed: () => _openMap(address.fullAddress),
                      ),
                    ],
                  );
                }).toList(),
              ),

            // Websites
            if (contact.websites.isNotEmpty)
              _buildSectionCard(
                context,
                'Website',
                Icons.language,
                contact.websites.map((website) {
                  return _buildActionRow(
                    website.label ?? 'Website',
                    website.url,
                    [
                      IconButton(
                        icon: const Icon(Icons.open_in_browser,
                            color: Colors.blue),
                        onPressed: () => _openUrl(website.url),
                      ),
                    ],
                  );
                }).toList(),
              ),

            // Events (birthdays, anniversaries)
            if (contact.events.isNotEmpty)
              _buildSectionCard(
                context,
                'Events',
                Icons.cake,
                contact.events.map((event) {
                  return _buildInfoRow(
                    event.label ?? 'Event',
                    event.date != null
                        ? '${event.date!.day}/${event.date!.month}/${event.date!.year}'
                        : 'No date',
                  );
                }).toList(),
              ),

            // Social media accounts
            if (contact.socialAccounts.isNotEmpty)
              _buildSectionCard(
                context,
                'Social',
                Icons.people,
                contact.socialAccounts.map((account) {
                  return _buildInfoRow(
                    account.platform ?? 'Account',
                    account.username,
                  );
                }).toList(),
              ),

            // Relations
            if (contact.relations.isNotEmpty)
              _buildSectionCard(
                context,
                'Relations',
                Icons.people_alt,
                contact.relations.map((relation) {
                  return _buildInfoRow(
                    relation.type ?? 'Relation',
                    relation.name,
                  );
                }).toList(),
              ),

            // Notes
            if (contact.note != null && contact.note!.isNotEmpty)
              _buildSectionCard(
                context,
                'Notes',
                Icons.note,
                [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(contact.note!),
                  ),
                ],
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildContactHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Hero(
            tag: 'contact-${contact.id}',
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: _getContactImage(),
              child: _getContactInitial(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            contact.displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (contact.jobTitle != null && contact.company != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${contact.jobTitle} at ${contact.company}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            )
          else if (contact.jobTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                contact.jobTitle!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            )
          else if (contact.company != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                contact.company!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (contact.phones.isNotEmpty || contact.emails.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      Icons.phone,
                      'Call',
                      Colors.green,
                      () => _makePhoneCall(contact.phones.first.number),
                    ),
                  if (contact.phones.isNotEmpty)
                    _buildQuickAction(
                      context,
                      Icons.message,
                      'Text',
                      Colors.blue,
                      () => _sendSMS(contact.phones.first.number),
                    ),
                  if (contact.emails.isNotEmpty)
                    _buildQuickAction(
                      context,
                      Icons.email,
                      'Email',
                      Colors.red,
                      () => _sendEmail(contact.emails.first.address),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: 20,
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(
    String label,
    String value,
    List<Widget> actions,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }

  // Helper methods for contact image
  ImageProvider? _getContactImage() {
    if (contact.photoBytes == null) return null;

    try {
      return MemoryImage(base64Decode(contact.photoBytes!));
    } catch (e) {
      // If there's an error decoding the image, return null
      return null;
    }
  }

  Widget? _getContactInitial() {
    // Only show initial if there's no photo or if photo loading failed
    if (contact.photoBytes == null || _getContactImage() == null) {
      return Text(
        contact.displayName.isNotEmpty
            ? contact.displayName[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 30,
        ),
      );
    }
    return null;
  }

  // Action methods
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  Future<void> _sendSMS(String phoneNumber) async {
    // First attempt: Modern approach with URI encoding
    final Uri uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': ''}, // Empty body to just open the SMS app
    );

    try {
      // Check if the primary URI can be launched
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri);
      } else {
        // Second attempt: Try smsto: scheme (works better on some Android devices)
        final Uri fallbackUri = Uri.parse('smsto:$phoneNumber');
        if (await url_launcher.canLaunchUrl(fallbackUri)) {
          await url_launcher.launchUrl(fallbackUri);
        } else {
          // Third attempt: Try sms: without query parameters
          final Uri simpleSmsUri = Uri(scheme: 'sms', path: phoneNumber);
          if (await url_launcher.canLaunchUrl(simpleSmsUri)) {
            await url_launcher.launchUrl(simpleSmsUri);
          } else {
            throw Exception('Could not launch messaging app');
          }
        }
      }
    } catch (e) {
      print('Error launching SMS app: $e');
      // Optional: Show a snackbar or other UI feedback
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri uri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $uri';
    }
  }

  Future<void> _openMap(String address) async {
    final Uri uri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/search/',
      queryParameters: {'api': '1', 'query': address},
    );
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri);
    }
  }

  Future<void> _openUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (await url_launcher.canLaunchUrl(uri)) {
      await url_launcher.launchUrl(uri,
          mode: url_launcher.LaunchMode.externalApplication);
    }
  }
}
