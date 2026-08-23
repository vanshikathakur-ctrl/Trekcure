import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class MedicalInformationScreen extends StatefulWidget {
  const MedicalInformationScreen({super.key});

  @override
  State<MedicalInformationScreen> createState() =>
      _MedicalInformationScreenState();
}

class _MedicalInformationScreenState extends State<MedicalInformationScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _saving = false;
  String? _bloodGroup;

  bool _allergies = false;
  bool _asthma = false;
  bool _diabetes = false;
  bool _heartCondition = false;
  bool _epilepsy = false;
  bool _hypertension = false;
  bool _medications = false;
  bool _otherCondition = false;

  final TextEditingController _allergyController = TextEditingController();
  final TextEditingController _asthmaController = TextEditingController();
  final TextEditingController _diabetesController = TextEditingController();
  final TextEditingController _heartController = TextEditingController();
  final TextEditingController _epilepsyController = TextEditingController();
  final TextEditingController _hypertensionController = TextEditingController();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  final TextEditingController _emergencyNotesController =
      TextEditingController();

  // Android Emulator -> Windows localhost
  static const String _apiBaseUrl = 'http://10.0.2.2:8000';

  @override
  void dispose() {
    _allergyController.dispose();
    _asthmaController.dispose();
    _diabetesController.dispose();
    _heartController.dispose();
    _epilepsyController.dispose();
    _hypertensionController.dispose();
    _medicationController.dispose();
    _otherController.dispose();
    _emergencyNotesController.dispose();
    super.dispose();
  }

  Future<void> _saveMedicalInformation() async {
    if (_saving) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please log in before saving medical information.',
        isError: true,
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final Map<String, dynamic> medicalData = {
        'user_id': user.id,
        'blood_group': _bloodGroup,
        'allergies': _allergies,
        'allergy_details': _allergies ? _allergyController.text.trim() : null,
        'asthma': _asthma,
        'asthma_details': _asthma ? _asthmaController.text.trim() : null,
        'diabetes': _diabetes,
        'diabetes_details': _diabetes ? _diabetesController.text.trim() : null,
        'heart_condition': _heartCondition,
        'heart_condition_details': _heartCondition
            ? _heartController.text.trim()
            : null,
        'epilepsy': _epilepsy,
        'epilepsy_details': _epilepsy ? _epilepsyController.text.trim() : null,
        'hypertension': _hypertension,
        'hypertension_details': _hypertension
            ? _hypertensionController.text.trim()
            : null,
        'medications': _medications,
        'medication_details': _medications
            ? _medicationController.text.trim()
            : null,
        'other_condition': _otherCondition,
        'other_condition_details': _otherCondition
            ? _otherController.text.trim()
            : null,
        'emergency_notes': _emergencyNotesController.text.trim(),
      };

      // Create the cryptographic hash through FastAPI.
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/save-medical-information'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(medicalData),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'Medical API error (${response.statusCode}): ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid response from medical API.');
      }

      final medicalHash = decoded['medical_hash']?.toString();
      if (medicalHash == null || medicalHash.isEmpty) {
        throw Exception('Medical hash was not returned by the server.');
      }

      medicalData['medical_hash'] = medicalHash;

      // Store the actual medical details in Supabase.
      await _supabase
          .from('medical_information')
          .upsert(medicalData, onConflict: 'user_id');

      if (!mounted) return;

      _showMessage('Medical information saved successfully.');

      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('SAVE MEDICAL INFORMATION ERROR: $e');

      if (!mounted) return;

      _showMessage('Could not save medical information.\n$e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Widget _detailsField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(
            Icons.edit_note,
            color: AppColors.primaryGreen,
          ),
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _medicalCheckbox({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required Widget detailsField,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          children: [
            CheckboxListTile(
              value: value,
              onChanged: onChanged,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primaryGreen,
              secondary: Icon(icon, color: AppColors.primaryGreen),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (value) detailsField,
          ],
        ),
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _saving ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'Medical Information',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppCard(
                color: AppColors.lightGreenBg,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.health_and_safety,
                      color: AppColors.primaryGreen,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select the medical conditions that apply to you. The details can help emergency responders provide safer assistance.',
                        style: TextStyle(fontSize: 13.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Blood Group',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _bloodGroup,
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.bloodtype_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  hintText: 'Select blood group',
                ),
                items: const [
                  DropdownMenuItem(value: 'A+', child: Text('A+')),
                  DropdownMenuItem(value: 'A-', child: Text('A-')),
                  DropdownMenuItem(value: 'B+', child: Text('B+')),
                  DropdownMenuItem(value: 'B-', child: Text('B-')),
                  DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                  DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                  DropdownMenuItem(value: 'O+', child: Text('O+')),
                  DropdownMenuItem(value: 'O-', child: Text('O-')),
                  DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
                ],
                onChanged: (value) {
                  setState(() {
                    _bloodGroup = value;
                  });
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Medical Conditions',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tick a condition to reveal the details field.',
                style: TextStyle(color: AppColors.textGrey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _medicalCheckbox(
                title: 'Allergies',
                icon: Icons.warning_amber_outlined,
                value: _allergies,
                onChanged: (value) =>
                    setState(() => _allergies = value ?? false),
                detailsField: _detailsField(
                  controller: _allergyController,
                  hint: 'Example: penicillin, peanuts, bee sting...',
                ),
              ),
              _medicalCheckbox(
                title: 'Asthma',
                icon: Icons.air,
                value: _asthma,
                onChanged: (value) => setState(() => _asthma = value ?? false),
                detailsField: _detailsField(
                  controller: _asthmaController,
                  hint: 'Severity, inhaler, medication, instructions...',
                ),
              ),
              _medicalCheckbox(
                title: 'Diabetes',
                icon: Icons.water_drop_outlined,
                value: _diabetes,
                onChanged: (value) =>
                    setState(() => _diabetes = value ?? false),
                detailsField: _detailsField(
                  controller: _diabetesController,
                  hint: 'Type, medication, insulin information...',
                ),
              ),
              _medicalCheckbox(
                title: 'Heart Condition',
                icon: Icons.favorite_border,
                value: _heartCondition,
                onChanged: (value) =>
                    setState(() => _heartCondition = value ?? false),
                detailsField: _detailsField(
                  controller: _heartController,
                  hint: 'Condition, medication, emergency instructions...',
                ),
              ),
              _medicalCheckbox(
                title: 'Epilepsy / Seizure Disorder',
                icon: Icons.monitor_heart_outlined,
                value: _epilepsy,
                onChanged: (value) =>
                    setState(() => _epilepsy = value ?? false),
                detailsField: _detailsField(
                  controller: _epilepsyController,
                  hint: 'Medication, triggers, emergency instructions...',
                ),
              ),
              _medicalCheckbox(
                title: 'Hypertension',
                icon: Icons.favorite_outline,
                value: _hypertension,
                onChanged: (value) =>
                    setState(() => _hypertension = value ?? false),
                detailsField: _detailsField(
                  controller: _hypertensionController,
                  hint: 'Medication, severity, emergency instructions...',
                ),
              ),
              _medicalCheckbox(
                title: 'Regular Medication',
                icon: Icons.medication_outlined,
                value: _medications,
                onChanged: (value) =>
                    setState(() => _medications = value ?? false),
                detailsField: _detailsField(
                  controller: _medicationController,
                  hint: 'Medicine name, dosage, frequency...',
                ),
              ),
              _medicalCheckbox(
                title: 'Other Medical Condition',
                icon: Icons.medical_information_outlined,
                value: _otherCondition,
                onChanged: (value) =>
                    setState(() => _otherCondition = value ?? false),
                detailsField: _detailsField(
                  controller: _otherController,
                  hint: 'Describe any other important condition...',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Emergency Notes',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emergencyNotesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Anything an emergency responder should know...',
                  prefixIcon: Icon(
                    Icons.emergency_outlined,
                    color: AppColors.dangerRed,
                  ),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveMedicalInformation,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.lock_outline),
                  label: Text(
                    _saving ? 'Saving...' : 'Save Medical Information',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'Medical details are stored separately from the Digital ID.\nOnly a cryptographic hash is associated with the Digital ID.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
