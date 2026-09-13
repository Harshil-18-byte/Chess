import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final render3dProvider = NotifierProvider<Render3dNotifier, bool>(Render3dNotifier.new);

class Render3dNotifier extends Notifier<bool> {
  static const _key = 'chess_render_3d';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setRender3d(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
  }
}

final reduceMotionProvider = NotifierProvider<ReduceMotionNotifier, bool>(ReduceMotionNotifier.new);

class ReduceMotionNotifier extends Notifier<bool> {
  static const _key = 'chess_reduce_motion';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> setReduceMotion(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
  }
}

final pushEnabledProvider = NotifierProvider<PushEnabledNotifier, bool>(PushEnabledNotifier.new);

class PushEnabledNotifier extends Notifier<bool> {
  static const _key = 'chess_push_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? true;
  }

  Future<void> setPushEnabled(bool value) async {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, value);
    
    // Sync to firestore if logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'pushEnabled': value,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }
}
