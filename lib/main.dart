import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/constants/app_constants.dart';
import 'firebase_options.dart';
import 'injection_container.dart';
import 'native_bridge/whisper_lifecycle_observer.dart';
import 'native_bridge/whisper_model_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await configureDependencies();
  await getIt<WhisperModelManager>().preloadDefaultModels(
    [AppConstants.whisperDefaultModel],
  );
  getIt<WhisperLifecycleObserver>().start();
  runApp(const SmartTutorLiteApp());
}
