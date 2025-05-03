import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Model/contact_model.dart';
import '../ViewModel/Contact_Bloc/contact_bloc.dart';
import '../ViewModel/Contact_Bloc/contact_event.dart';
import '../ViewModel/Contact_Bloc/contact_state.dart';

class ContactFormScreen extends StatefulWidget {
  final ContactModel? contact;
  final bool isEditing;

  const ContactFormScreen({
    Key? key,
    this.contact,
    this.isEditing = false,
  }) : super(key: key);

  @override
  State<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends State<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _companyController;
  late TextEditingController _jobTitleController;
  late TextEditingController _noteController;
  
  List<PhoneController> _phoneControllers = [];
  List<EmailController> _emailControllers = [];
  List<AddressController> _addressControllers = [];
  List<WebsiteController> _websiteControllers = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    // Initialize basic info controllers
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _companyController = TextEditingController();
    _jobTitleController = TextEditingController();
    _noteController = TextEditingController();

    if (widget.isEditing && widget.contact != null) {
      // Fill in existing data if editing
      final nameParts = widget.contact!.displayName.split(' ');
      if (nameParts.isNotEmpty) {
        _firstNameController.text = nameParts.first;
        if (nameParts.length > 1) {
          _lastNameController.text = nameParts.sublist(1).join(' ');
        }
      }
      
      _companyController.text = widget.contact!.company ?? '';
      _jobTitleController.text = widget.contact!.jobTitle ?? '';
      _noteController.text = widget.contact!.note ?? '';

      // Initialize phone controllers
      _phoneControllers = widget.contact!.phones.map((phone) => 
        PhoneController(
          numberController: TextEditingController(text: phone.number),
          label: phone.label ?? 'mobile',
        )
      ).toList();
      
      // Initialize email controllers
      _emailControllers = widget.contact!.emails.map((email) => 
        EmailController(
          addressController: TextEditingController(text: email.address),
          label: email.label ?? 'home',
        )
      ).toList();
      
      // Initialize address controllers
      _addressControllers = widget.contact!.addresses.map((address) => 
        AddressController(
          streetController: TextEditingController(text: address.street ?? ''),
          cityController: TextEditingController(text: address.city ?? ''),
          regionController: TextEditingController(text: address.region ?? ''),
          postalCodeController: TextEditingController(text: address.postalCode ?? ''),
          countryController: TextEditingController(text: address.country ?? ''),
          label: address.label ?? 'home',
        )
      ).toList();
      
      // Initialize website controllers
      _websiteControllers = widget.contact!.websites.map((website) => 
        WebsiteController(
          urlController: TextEditingController(text: website.url),
          label: website.label ?? 'home',
        )
      ).toList();
    }
    
    // Add default phone field if none exists
    if (_phoneControllers.isEmpty) {
      _phoneControllers.add(PhoneController(
        numberController: TextEditingController(),
        label: 'mobile',
      ));
    }
    
    // Add default email field if none exists
    if (_emailControllers.isEmpty) {
      _emailControllers.add(EmailController(
        addressController: TextEditingController(),
        label: 'home',
      ));
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _noteController.dispose();
    
    for (var controller in _phoneControllers) {
      controller.numberController.dispose();
    }
    
    for (var controller in _emailControllers) {
      controller.addressController.dispose();
    }
    
    for (var controller in _addressControllers) {
      controller.streetController.dispose();
      controller.cityController.dispose();
      controller.regionController.dispose();
      controller.postalCodeController.dispose();
      controller.countryController.dispose();
    }
    
    for (var controller in _websiteControllers) {
      controller.urlController.dispose();
    }
    
    super.dispose();
  }

  void _addPhone() {
    setState(() {
      _phoneControllers.add(PhoneController(
        numberController: TextEditingController(),
        label: 'mobile',
      ));
    });
  }

  void _removePhone(int index) {
    if (_phoneControllers.length > 1) {
      setState(() {
        _phoneControllers[index].numberController.dispose();
        _phoneControllers.removeAt(index);
      });
    }
  }

  void _addEmail() {
    setState(() {
      _emailControllers.add(EmailController(
        addressController: TextEditingController(),
        label: 'home',
      ));
    });
  }

  void _removeEmail(int index) {
    if (_emailControllers.length > 1) {
      setState(() {
        _emailControllers[index].addressController.dispose();
        _emailControllers.removeAt(index);
      });
    }
  }

  void _addAddress() {
    setState(() {
      _addressControllers.add(AddressController(
        streetController: TextEditingController(),
        cityController: TextEditingController(),
        regionController: TextEditingController(),
        postalCodeController: TextEditingController(),
        countryController: TextEditingController(),
        label: 'home',
      ));
    });
  }

  void _removeAddress(int index) {
    setState(() {
      _addressControllers[index].streetController.dispose();
      _addressControllers[index].cityController.dispose();
      _addressControllers[index].regionController.dispose();
      _addressControllers[index].postalCodeController.dispose();
      _addressControllers[index].countryController.dispose();
      _addressControllers.removeAt(index);
    });
  }

  void _addWebsite() {
    setState(() {
      _websiteControllers.add(WebsiteController(
        urlController: TextEditingController(),
        label: 'home',
      ));
    });
  }

  void _removeWebsite(int index) {
    setState(() {
      _websiteControllers[index].urlController.dispose();
      _websiteControllers.removeAt(index);
    });
  }

  void _saveContact() {
    if (_formKey.currentState!.validate()) {
      // Create a new contact model from form data
      final displayName = '${_firstNameController.text} ${_lastNameController.text}'.trim();
      
      final phones = _phoneControllers.map((controller) => 
        PhoneNumber(
          number: controller.numberController.text,
          label: controller.label,
        )
      ).toList();
      
      final emails = _emailControllers.map((controller) => 
        ContactEmail(
          address: controller.addressController.text,
          label: controller.label,
        )
      ).toList();
      
      final addresses = _addressControllers.map((controller) => 
        ContactAddress(
          street: controller.streetController.text,
          city: controller.cityController.text,
          region: controller.regionController.text,
          postalCode: controller.postalCodeController.text,
          country: controller.countryController.text,
          label: controller.label,
        )
      ).toList();
      
      final websites = _websiteControllers.map((controller) => 
        ContactWebsite(
          url: controller.urlController.text,
          label: controller.label,
        )
      ).toList();
      
      final contact = ContactModel(
        id: widget.isEditing ? widget.contact!.id : '',
        displayName: displayName,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        phones: phones,
        emails: emails,
        addresses: addresses,
        websites: websites,
        company: _companyController.text.isNotEmpty ? _companyController.text : null,
        jobTitle: _jobTitleController.text.isNotEmpty ? _jobTitleController.text : null,
        note: _noteController.text.isNotEmpty ? _noteController.text : null,
        photoBytes: widget.isEditing ? widget.contact!.photoBytes : null,
        events: [],
      );
      
      if (widget.isEditing) {
        // Update existing contact
        context.read<ContactBloc>().add(UpdateContact(contact: contact));
      } else {
        // Add new contact
        context.read<ContactBloc>().add(AddContact(contact: contact));
      }
      
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Contact' : 'Add Contact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveContact,
          ),
        ],
      ),
      body: BlocListener<ContactBloc, ContactState>(
        listener: (context, state) {
          if (state is ContactLoaded && state.operationStatus != null) {
            final status = state.operationStatus!;
            if (status.isSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(status.message)),
              );
            }
          } else if (state is ContactError && state.operationStatus != null) {
            final status = state.operationStatus!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(status.message), backgroundColor: Colors.red),
            );
          }
        },
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Basic Info Section
                _buildSectionHeader('Basic Information'),
                _buildNameFields(),
                const SizedBox(height: 16),
                _buildCompanyFields(),
                const SizedBox(height: 24),
                
                // Phone Section
                _buildSectionHeader('Phone Numbers'),
                ..._buildPhoneFields(),
                _buildAddButton('Add Phone', _addPhone),
                const SizedBox(height: 24),
                
                // Email Section
                _buildSectionHeader('Email Addresses'),
                ..._buildEmailFields(),
                _buildAddButton('Add Email', _addEmail),
                const SizedBox(height: 24),
                
                // Address Section
                _buildSectionHeader('Addresses'),
                ..._buildAddressFields(),
                _buildAddButton('Add Address', _addAddress),
                const SizedBox(height: 24),
                
                // Website Section
                _buildSectionHeader('Websites'),
                ..._buildWebsiteFields(),
                _buildAddButton('Add Website', _addWebsite),
                const SizedBox(height: 24),
                
                // Notes Section
                _buildSectionHeader('Notes'),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    hintText: 'Add notes',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNameFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a first name';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompanyFields() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _companyController,
            decoration: const InputDecoration(
              labelText: 'Company',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _jobTitleController,
            decoration: const InputDecoration(
              labelText: 'Job Title',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPhoneFields() {
    return List.generate(_phoneControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _phoneControllers[index].numberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (index == 0 && (value == null || value.isEmpty)) {
                    return 'Please enter at least one phone number';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _phoneControllers[index].label,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                  DropdownMenuItem(value: 'home', child: Text('Home')),
                  DropdownMenuItem(value: 'work', child: Text('Work')),
                  DropdownMenuItem(value: 'main', child: Text('Main')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _phoneControllers[index].label = value;
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _phoneControllers.length > 1 ? () => _removePhone(index) : null,
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildEmailFields() {
    return List.generate(_emailControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _emailControllers[index].addressController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Simple email validation
                    if (!value.contains('@') || !value.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _emailControllers[index].label,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'home', child: Text('Home')),
                  DropdownMenuItem(value: 'work', child: Text('Work')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _emailControllers[index].label = value;
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _emailControllers.length > 1 ? () => _removeEmail(index) : null,
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildAddressFields() {
    return List.generate(_addressControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _addressControllers[index].label,
                        decoration: const InputDecoration(
                          labelText: 'Address Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'home', child: Text('Home')),
                          DropdownMenuItem(value: 'work', child: Text('Work')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _addressControllers[index].label = value;
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeAddress(index),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressControllers[index].streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _addressControllers[index].cityController,
                        decoration: const InputDecoration(
                          labelText: 'City',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _addressControllers[index].regionController,
                        decoration: const InputDecoration(
                          labelText: 'State/Province',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _addressControllers[index].postalCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Postal Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _addressControllers[index].countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  List<Widget> _buildWebsiteFields() {
    return List.generate(_websiteControllers.length, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _websiteControllers[index].urlController,
                decoration: const InputDecoration(
                  labelText: 'Website URL',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Simple URL validation
                    if (!value.contains('.')) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _websiteControllers[index].label,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'home', child: Text('Home')),
                  DropdownMenuItem(value: 'work', child: Text('Work')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _websiteControllers[index].label = value;
                    });
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _removeWebsite(index),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return TextButton.icon(
      icon: const Icon(Icons.add_circle_outline),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

// Helper classes to manage form controllers
class PhoneController {
  final TextEditingController numberController;
  String label;

  PhoneController({
    required this.numberController,
    required this.label,
  });
}

class EmailController {
  final TextEditingController addressController;
  String label;

  EmailController({
    required this.addressController,
    required this.label,
  });
}

class AddressController {
  final TextEditingController streetController;
  final TextEditingController cityController;
  final TextEditingController regionController;
  final TextEditingController postalCodeController;
  final TextEditingController countryController;
  String label;

  AddressController({
    required this.streetController,
    required this.cityController,
    required this.regionController,
    required this.postalCodeController,
    required this.countryController,
    required this.label,
  });
}

class WebsiteController {
  final TextEditingController urlController;
  String label;

  WebsiteController({
    required this.urlController,
    required this.label,
  });
}
