import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

class MedicalInformationProfileScreen extends StatefulWidget {
  const MedicalInformationProfileScreen({super.key});

  @override
  State<MedicalInformationProfileScreen> createState() =>
      _MedicalInformationScreenState();
}

class _MedicalInformationScreenState
    extends State<MedicalInformationProfileScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _allergiesController = TextEditingController();

  final TextEditingController _medicationsController = TextEditingController();

  final TextEditingController _emergencyNotesController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _loading = true;
  bool _saving = false;

  String? _bloodGroup;

  final Set<String> _selectedConditions = {};

  // ============================================================
  // AVAILABLE BLOOD GROUPS
  // ============================================================

  final List<String> _bloodGroups = const [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  // ============================================================
  // AVAILABLE MEDICAL CONDITIONS
  // ============================================================

  final List<String> _conditions = const [
    'Allergies',
    'Asthma',
    'Diabetes',
    'Heart Condition',
    'Epilepsy / Seizure Disorder',
    'High Blood Pressure',
    'Low Blood Pressure',
    'Kidney Disease',
    'Liver Disease',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadMedicalInformation();
  }

  // ============================================================
  // LOAD MEDICAL INFORMATION
  // ============================================================

  Future<void> _loadMedicalInformation() async {
    final user = _supabase.auth.currentUser;

    debugPrint('MEDICAL INFO: Current user = ${user?.id}');

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _message('You are not logged in.', isError: true);

      return;
    }

    try {
      final response = await _supabase
          .from('medical_information')
          .select(
            'blood_group, allergies, current_medications, '
            'medical_conditions, emergency_notes',
          )
          .eq('user_id', user.id)
          .maybeSingle();

      debugPrint('MEDICAL INFO LOAD RESPONSE: $response');

      if (response != null) {
        _bloodGroup = response['blood_group']?.toString();

        _allergiesController.text = response['allergies']?.toString() ?? '';

        _medicationsController.text =
            response['current_medications']?.toString() ?? '';

        _emergencyNotesController.text =
            response['emergency_notes']?.toString() ?? '';

        final conditions = response['medical_conditions']?.toString() ?? '';

        if (conditions.isNotEmpty) {
          final savedConditions = conditions
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);

          _selectedConditions.addAll(savedConditions);
        }
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('==================================================');
      debugPrint('MEDICAL INFORMATION LOAD ERROR');
      debugPrint('$e');
      debugPrint('$stackTrace');
      debugPrint('==================================================');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _message('Could not load medical information: $e', isError: true);
    }
  }

  // ============================================================
  // SAVE MEDICAL INFORMATION
  // ============================================================

  Future<void> _saveMedicalInformation() async {
    final user = _supabase.auth.currentUser;

    // ==========================================================
    // CHECK LOGIN
    // ==========================================================

    if (user == null) {
      _message('You are not logged in.', isError: true);
      return;
    }

    // ==========================================================
    // CHECK BLOOD GROUP
    // ==========================================================

    if (_bloodGroup == null || _bloodGroup!.isEmpty) {
      _message('Please select your blood group.', isError: true);
      return;
    }

    // ==========================================================
    // PREVENT DOUBLE SAVE
    // ==========================================================

    if (_saving) return;

    setState(() {
      _saving = true;
    });

    try {
      // ========================================================
      // PREPARE DATA
      // ========================================================

      final conditions = _selectedConditions.join(', ');

      final data = {
        'user_id': user.id,
        'blood_group': _bloodGroup,
        'allergies': _allergiesController.text.trim(),
        'current_medications': _medicationsController.text.trim(),
        'medical_conditions': conditions,
        'emergency_notes': _emergencyNotesController.text.trim(),
      };

      debugPrint('==================================================');
      debugPrint('MEDICAL INFORMATION SAVE');
      debugPrint('User ID: ${user.id}');
      debugPrint('Data: $data');
      debugPrint('==================================================');

      // ========================================================
      // CHECK EXISTING RECORD
      // ========================================================

      final existing = await _supabase
          .from('medical_information')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      debugPrint('EXISTING MEDICAL RECORD: $existing');

      // ========================================================
      // UPDATE EXISTING RECORD
      // ========================================================

      if (existing != null) {
        debugPrint('MEDICAL INFO: Updating existing record...');

        final updateResponse = await _supabase
            .from('medical_information')
            .update({
              'blood_group': _bloodGroup,
              'allergies': _allergiesController.text.trim(),
              'current_medications': _medicationsController.text.trim(),
              'medical_conditions': conditions,
              'emergency_notes': _emergencyNotesController.text.trim(),
            })
            .eq('user_id', user.id)
            .select();

        debugPrint('MEDICAL INFO UPDATE RESPONSE: $updateResponse');
      }
      // ========================================================
      // INSERT NEW RECORD
      // ========================================================
      else {
        debugPrint('MEDICAL INFO: Creating new record...');

        final insertResponse = await _supabase
            .from('medical_information')
            .insert(data)
            .select();

        debugPrint('MEDICAL INFO INSERT RESPONSE: $insertResponse');
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _message('Medical information saved successfully.');

      await Future.delayed(const Duration(milliseconds: 700));

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      // ========================================================
      // PRINT ACTUAL ERROR
      // ========================================================

      debugPrint('==================================================');
      debugPrint('MEDICAL INFORMATION SAVE ERROR');
      debugPrint('ERROR TYPE: ${e.runtimeType}');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE:');
      debugPrint('$stackTrace');
      debugPrint('==================================================');

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      // ========================================================
      // SHOW ACTUAL ERROR
      // ========================================================

      _message('Save failed: $e', isError: true);
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _message(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 5, overflow: TextOverflow.ellipsis),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        backgroundColor: isError ? AppColors.dangerRed : AppColors.primaryGreen,
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primaryGreen,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONDITION TILE
  // ============================================================

  Widget _conditionTile(String condition, IconData icon) {
    final selected = _selectedConditions.contains(condition);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.primaryGreen : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(
          condition,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Checkbox(
          value: selected,
          activeColor: AppColors.primaryGreen,
          onChanged: (value) {
            setState(() {
              if (value == true) {
                _selectedConditions.add(condition);
              } else {
                _selectedConditions.remove(condition);
              }
            });
          },
        ),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedConditions.remove(condition);
            } else {
              _selectedConditions.add(condition);
            }
          });
        },
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Android back button is intentionally allowed.
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: true,

          leading: IconButton(
            icon: const Icon(Icons.arrow_back, size: 25),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),

          title: const Text(
            'Medical Information',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),

        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
                  children: [
                    // ==================================================
                    // INFORMATION CARD
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreenBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.primaryGreen.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.medical_services_outlined,
                              color: Colors.white,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'Add important medical information that may help emergency responders provide appropriate assistance.',
                              style: TextStyle(fontSize: 14, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // BLOOD GROUP
                    // ==================================================
                    const Text(
                      'Blood Group',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonFormField<String>(
                        initialValue: _bloodGroup,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.bloodtype_outlined),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                        ),
                        hint: const Text('Select blood group'),
                        items: _bloodGroups
                            .map(
                              (group) => DropdownMenuItem<String>(
                                value: group,
                                child: Text(group),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _bloodGroup = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ==================================================
                    // MEDICAL CONDITIONS
                    // ==================================================
                    const Text(
                      'Medical Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      'Select only the conditions that apply to you.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 14),

                    _conditionTile('Allergies', Icons.warning_amber_outlined),

                    _conditionTile('Asthma', Icons.air),

                    _conditionTile('Diabetes', Icons.water_drop_outlined),

                    _conditionTile('Heart Condition', Icons.favorite_border),

                    _conditionTile(
                      'Epilepsy / Seizure Disorder',
                      Icons.monitor_heart_outlined,
                    ),

                    _conditionTile(
                      'High Blood Pressure',
                      Icons.favorite_outline,
                    ),

                    _conditionTile(
                      'Low Blood Pressure',
                      Icons.bloodtype_outlined,
                    ),

                    _conditionTile('Kidney Disease', Icons.water_drop_outlined),

                    _conditionTile(
                      'Liver Disease',
                      Icons.health_and_safety_outlined,
                    ),

                    _conditionTile('Other', Icons.medical_information_outlined),

                    const SizedBox(height: 16),

                    // ==================================================
                    // ALLERGIES
                    // ==================================================
                    _textField(
                      controller: _allergiesController,
                      label: 'Allergies',
                      hint: 'Example: Peanuts, Penicillin',
                      icon: Icons.warning_amber_outlined,
                    ),

                    // ==================================================
                    // MEDICATIONS
                    // ==================================================
                    _textField(
                      controller: _medicationsController,
                      label: 'Current Medications',
                      hint: 'Example: Paracetamol',
                      icon: Icons.medication_outlined,
                    ),

                    // ==================================================
                    // EMERGENCY NOTES
                    // ==================================================
                    _textField(
                      controller: _emergencyNotesController,
                      label: 'Emergency Medical Notes',
                      hint: 'Enter any important information emergency responders should know.',
                      icon: Icons.note_alt_outlined,
                      maxLines: 4,
                    ),

                    const SizedBox(height: 8),

                    // ==================================================
                    // SAVE BUTTON
                    // ==================================================
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveMedicalInformation,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Save Medical Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // FOOTER
                    // ==================================================
                    const Text(
                      'You can update this information anytime from Profile → Medical Information.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _allergiesController.dispose();
    _medicationsController.dispose();
    _emergencyNotesController.dispose();

    super.dispose();
  }
}
