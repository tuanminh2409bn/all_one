import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_data.dart';
import 'auth_service.dart';

Future<void> initializeUserData(AuthService auth, {AppDataStore? store}) async {
  final target = store ?? AppDataStore.shared;
  await target.initialize(auth.dataScope);
  final userId = auth.firebaseUserId;
  if (userId != null) {
    unawaited(
      target.enableCloudSync(
        firestore: FirebaseFirestore.instance,
        userId: userId,
      ),
    );
  }
}
