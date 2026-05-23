import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PrivacyPreferences {
  final bool discoverableProfile;
  final bool showActivitySummary;
  final bool showCollectionsPublicly;
  final bool allowFollowers;

  const PrivacyPreferences({
    this.discoverableProfile = true,
    this.showActivitySummary = true,
    this.showCollectionsPublicly = true,
    this.allowFollowers = true,
  });

  factory PrivacyPreferences.fromMap(Map<String, dynamic> map) {
    return PrivacyPreferences(
      discoverableProfile: map['discoverable_profile'] != false,
      showActivitySummary: map['show_activity_summary'] != false,
      showCollectionsPublicly: map['show_collections_publicly'] != false,
      allowFollowers: map['allow_followers'] != false,
    );
  }

  Map<String, dynamic> toMap() => {
    'discoverable_profile': discoverableProfile,
    'show_activity_summary': showActivitySummary,
    'show_collections_publicly': showCollectionsPublicly,
    'allow_followers': allowFollowers,
  };

  PrivacyPreferences copyWith({
    bool? discoverableProfile,
    bool? showActivitySummary,
    bool? showCollectionsPublicly,
    bool? allowFollowers,
  }) {
    return PrivacyPreferences(
      discoverableProfile: discoverableProfile ?? this.discoverableProfile,
      showActivitySummary: showActivitySummary ?? this.showActivitySummary,
      showCollectionsPublicly:
          showCollectionsPublicly ?? this.showCollectionsPublicly,
      allowFollowers: allowFollowers ?? this.allowFollowers,
    );
  }
}

class PrivacySettingsService {
  PrivacySettingsService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  Future<PrivacyPreferences> loadPreferences() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const PrivacyPreferences();
    }

    try {
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      final rawPrefs = metadata['privacy_preferences'];
      if (rawPrefs is Map) {
        return PrivacyPreferences.fromMap(Map<String, dynamic>.from(rawPrefs));
      }
    } catch (error) {
      debugPrint('PrivacySettingsService.loadPreferences error: $error');
    }

    return const PrivacyPreferences();
  }

  Future<void> savePreferences(PrivacyPreferences prefs) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final metadata = Map<String, dynamic>.from(
      user.userMetadata ?? const <String, dynamic>{},
    );
    metadata['privacy_preferences'] = prefs.toMap();

    await _supabase.auth.updateUser(UserAttributes(data: metadata));
  }
}
