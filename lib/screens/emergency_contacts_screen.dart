// lib/screens/emergency_contacts_screen.dart
//
// Matches your existing TrekCure theme (AppColors / AppCard from
// lib/theme/app_theme.dart) and connects directly to the
// public.emergency_contacts table from schema.sql.
//
// Table it talks to:
//   emergency_contacts(id, user_id, contact_name, contact_phone, created_at)
// RLS already covers this — "Users manage emergency contacts" (FOR ALL
// USING auth.uid() = user_id) — so you never need to pass user_id manually
// on read, and Supabase blocks you from ever seeing someone else's rows.
//
// One-time setup if you haven't already:
//   1. flutter pub add supabase_flutter
//   2. In main.dart, before runApp():
//        await Supabase.initialize(
//          url: 'YOUR_SUPABASE_URL',
//          anonKey: 'YOUR_SUPABASE_ANON_KEY',
//        );
//   3. Make sure the user is signed in (supabase.auth.currentUser != null)
//      before this screen is reachable — emergency_contacts inserts need it.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../theme/app_theme.dart';

final supabase = Supabase.instance.client;

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  // READ — RLS auto-filters to the signed-in user's own rows
  Future<void> _fetchContacts() async {
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('emergency_contacts')
          .select()
          .order('created_at');
      setState(() => _contacts = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      _showError('Failed to load contacts: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // CREATE
  Future<void> _addContact(String name, String phone) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showError('You must be signed in to add a contact');
      return;
    }
    try {
      await supabase.from('emergency_contacts').insert({
        'user_id': userId,
        'contact_name': name,
        'contact_phone': phone,
      });
      await _fetchContacts();
    } catch (e) {
      _showError('Failed to add contact: $e');
    }
  }

  // DELETE
  Future<void> _deleteContact(String id) async {
    try {
      await supabase.from('emergency_contacts').delete().eq('id', id);
      await _fetchContacts();
    } catch (e) {
      _showError('Failed to delete contact: $e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showAddContactSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Emergency Contact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Contact name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(hintText: 'Phone number'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isEmpty || phone.isEmpty) {
                  _showError('Enter both name and phone number');
                  return;
                }
                Navigator.pop(ctx);
                _addContact(name, phone);
              },
              child: const Text('Save Contact'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Contacts')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryGreen,
        onPressed: _showAddContactSheet,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? const Center(
              child: Text(
                'No emergency contacts yet.\nTap + to add one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textGrey),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchContacts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _contacts.length,
                itemBuilder: (context, i) {
                  final contact = _contacts[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.lightGreenBg,
                            child: Icon(
                              Icons.person,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact['contact_name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  contact['contact_phone'] ?? '',
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.dangerRed,
                            ),
                            onPressed: () => _deleteContact(contact['id']),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
