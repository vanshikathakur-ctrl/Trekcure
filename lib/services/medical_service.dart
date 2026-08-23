import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MedicalService {
  MedicalService._();

  static final MedicalService instance = MedicalService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // CREATE / UPDATE MEDICAL PROFILE
  // ============================================================

  Future<String> saveMedicalProfile({
    required String? bloodGroup,
    required String criticalInformation,
    required bool emergencyAccess,
    required bool consent,
    required List<Map<String, dynamic>> allergies,
    required List<Map<String, dynamic>> conditions,
    required List<Map<String, dynamic>> medications,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not logged in.');
    }

    if (!consent) {
      throw Exception('Medical information consent is required.');
    }

    // ----------------------------------------------------------
    // CHECK EXISTING PROFILE
    // ----------------------------------------------------------

    final existing = await _supabase
        .from('medical_profiles')
        .select('id, record_version')
        .eq('user_id', user.id)
        .maybeSingle();

    final int version =
        ((existing?['record_version'] as int?) ?? 0) + 1;

    // ----------------------------------------------------------
    // CREATE CANONICAL DATA
    // ----------------------------------------------------------

    final medicalData = {
      'user_id': user.id,
      'blood_group': bloodGroup,
      'critical_information': criticalInformation,
      'emergency_access': emergencyAccess,
      'allergies': allergies,
      'conditions': conditions,
      'medications': medications,
      'record_version': version,
    };

    final canonicalJson = jsonEncode(
      _sortMap(medicalData),
    );

    final hash = sha256
        .convert(utf8.encode(canonicalJson))
        .toString();

    // ----------------------------------------------------------
    // UPSERT PROFILE
    // ----------------------------------------------------------

    final profile = await _supabase
        .from('medical_profiles')
        .upsert(
          {
            'user_id': user.id,
            'blood_group': bloodGroup,
            'critical_information': criticalInformation,
            'emergency_access': emergencyAccess,
            'consent': consent,
            'medical_record_hash': hash,
            'record_version': version,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        )
        .select('id')
        .single();

    final String profileId = profile['id'].toString();

    // ----------------------------------------------------------
    // REMOVE OLD CHILD RECORDS
    // ----------------------------------------------------------

    await _supabase
        .from('medical_allergies')
        .delete()
        .eq('medical_profile_id', profileId);

    await _supabase
        .from('medical_conditions')
        .delete()
        .eq('medical_profile_id', profileId);

    await _supabase
        .from('medical_medications')
        .delete()
        .eq('medical_profile_id', profileId);

    // ----------------------------------------------------------
    // INSERT ALLERGIES
    // ----------------------------------------------------------

    if (allergies.isNotEmpty) {
      await _supabase.from('medical_allergies').insert(
        allergies
            .map(
              (item) => {
                'medical_profile_id': profileId,
                'allergen': item['allergen'],
                'severity': item['severity'],
                'reaction': item['reaction'],
              },
            )
            .toList(),
      );
    }

    // ----------------------------------------------------------
    // INSERT CONDITIONS
    // ----------------------------------------------------------

    if (conditions.isNotEmpty) {
      await _supabase.from('medical_conditions').insert(
        conditions
            .map(
              (item) => {
                'medical_profile_id': profileId,
                'condition_name': item['condition_name'],
                'severity': item['severity'],
                'details': item['details'],
              },
            )
            .toList(),
      );
    }

    // ----------------------------------------------------------
    // INSERT MEDICATIONS
    // ----------------------------------------------------------

    if (medications.isNotEmpty) {
      await _supabase.from('medical_medications').insert(
        medications
            .map(
              (item) => {
                'medical_profile_id': profileId,
                'medicine_name': item['medicine_name'],
                'dosage': item['dosage'],
                'frequency': item['frequency'],
                'instructions': item['instructions'],
              },
            )
            .toList(),
      );
    }

    return hash;
  }

  // ============================================================
  // LOAD MEDICAL PROFILE
  // ============================================================

  Future<Map<String, dynamic>?> loadMedicalProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final profile = await _supabase
        .from('medical_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (profile == null) {
      return null;
    }

    final profileId = profile['id'].toString();

    final allergies = await _supabase
        .from('medical_allergies')
        .select()
        .eq('medical_profile_id', profileId);

    final conditions = await _supabase
        .from('medical_conditions')
        .select()
        .eq('medical_profile_id', profileId);

    final medications = await _supabase
        .from('medical_medications')
        .select()
        .eq('medical_profile_id', profileId);

    return {
      'profile': profile,
      'allergies': List<Map<String, dynamic>>.from(allergies),
      'conditions': List<Map<String, dynamic>>.from(conditions),
      'medications': List<Map<String, dynamic>>.from(medications),
    };
  }

  // ============================================================
  // SORT MAP FOR CONSISTENT HASH
  // ============================================================

  Map<String, dynamic> _sortMap(Map<String, dynamic> map) {
    final sortedKeys = map.keys.toList()..sort();

    final result = <String, dynamic>{};

    for (final key in sortedKeys) {
      final value = map[key];

      if (value is Map<String, dynamic>) {
        result[key] = _sortMap(value);
      } else if (value is List) {
        result[key] = value;
      } else {
        result[key] = value;
      }
    }

    return result;
  }
}