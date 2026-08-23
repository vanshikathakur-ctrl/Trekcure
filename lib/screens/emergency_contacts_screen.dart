// lib/screens/emergency_contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _contacts = [];

  bool _loading = true;
  bool _addingContact = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  // ============================================================
  // FETCH EMERGENCY CONTACTS
  // ============================================================

  Future<void> _fetchContacts() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        _showMessage('Please log in first.', isError: true);

        if (!mounted) return;

        setState(() {
          _contacts = [];
          _loading = false;
        });

        return;
      }

      final data = await _supabase
          .from('emergency_contacts')
          .select('id, user_id, contact_name, contact_phone, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _contacts = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Fetch emergency contacts error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Failed to load emergency contacts.', isError: true);
    }
  }

  // ============================================================
  // ADD CONTACT
  // ============================================================

  Future<void> _addContact(String name, String phone) async {
    if (_addingContact) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage('Please log in first.', isError: true);
      return;
    }

    setState(() {
      _addingContact = true;
    });

    try {
      await _supabase.from('emergency_contacts').insert({
        'user_id': user.id,
        'contact_name': name,
        'contact_phone': phone,
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      _showMessage('Emergency contact added successfully.');

      await _fetchContacts();
    } catch (e) {
      debugPrint('Add emergency contact error: $e');

      if (!mounted) return;

      _showMessage('Failed to add emergency contact.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _addingContact = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE CONTACT
  // ============================================================

  Future<void> _deleteContact(String contactId) async {
    try {
      await _supabase.from('emergency_contacts').delete().eq('id', contactId);

      if (!mounted) return;

      _showMessage('Emergency contact deleted.');

      await _fetchContacts();
    } catch (e) {
      debugPrint('Delete emergency contact error: $e');

      if (!mounted) return;

      _showMessage('Failed to delete contact.', isError: true);
    }
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<void> _confirmDelete(Map<String, dynamic> contact) async {
    final String name = contact['contact_name']?.toString() ?? 'this contact';

    final String? result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete Contact?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to remove $name from your emergency contacts?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 'cancel');
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, 'delete');
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.dangerRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'delete') {
      final id = contact['id'];

      if (id != null) {
        await _deleteContact(id.toString());
      }
    }
  }

  // ============================================================
  // ADD CONTACT BOTTOM SHEET
  // ============================================================

  void _showAddContactSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // HEADER
                    // ==================================================

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.lightGreenBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.contact_emergency,
                            color: AppColors.primaryGreen,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Add Emergency Contact',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // NAME
                    // ==================================================
                    const Text(
                      'Contact Name',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Father, Mother, Friend',
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // PHONE
                    // ==================================================
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Enter phone number',
                        prefixIcon: Icon(
                          Icons.phone_outlined,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // SAVE BUTTON
                    // ==================================================
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addingContact
                            ? null
                            : () {
                                final name = nameController.text.trim();

                                final phone = phoneController.text.trim();

                                if (name.isEmpty) {
                                  _showMessage(
                                    'Please enter the contact name.',
                                    isError: true,
                                  );
                                  return;
                                }

                                if (phone.isEmpty) {
                                  _showMessage(
                                    'Please enter the phone number.',
                                    isError: true,
                                  );
                                  return;
                                }

                                setSheetState(() {});

                                _addContact(name, phone);
                              },
                        icon: _addingContact
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _addingContact ? 'Saving...' : 'Save Contact',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.dangerRed : AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================

  Widget _buildContactCard(Map<String, dynamic> contact) {
    final String name = contact['contact_name']?.toString() ?? '';

    final String phone = contact['contact_phone']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: AppColors.lightGreenBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primaryGreen,
                size: 26,
              ),
            ),

            const SizedBox(width: 14),

            // Contact information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Unknown Contact' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Row(
                    children: [
                      const Icon(
                        Icons.phone_outlined,
                        size: 15,
                        color: AppColors.textGrey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          phone,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textGrey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Delete
            IconButton(
              tooltip: 'Delete contact',
              onPressed: () => _confirmDelete(contact),
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.dangerRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: AppColors.lightGreenBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.contact_emergency_outlined,
                size: 55,
                color: AppColors.primaryGreen,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'No Emergency Contacts',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Add trusted people who should be contacted during an emergency.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.textGrey,
              ),
            ),

            const SizedBox(height: 22),

            ElevatedButton.icon(
              onPressed: _showAddContactSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _fetchContacts,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ==========================================================
      // ADD BUTTON
      // ==========================================================
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        tooltip: 'Add emergency contact',
        onPressed: _showAddContactSheet,
        child: const Icon(Icons.add),
      ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _contacts.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _fetchContacts,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // Information card
                  AppCard(
                    color: AppColors.lightGreenBg,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: AppColors.primaryGreen,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'These contacts can be used by TrekCure during an emergency to help notify your trusted people.',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.4,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Your Emergency Contacts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),

                  const SizedBox(height: 12),

                  ..._contacts.map(_buildContactCard),
                ],
              ),
            ),
    );
  }
}
