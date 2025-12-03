import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/transcription_job.dart';
import '../../domain/entities/transcription_job_request.dart';
import '../models/transcription_job_model.dart';

abstract class TranscriptionJobRemoteDataSource {
  Future<TranscriptionJobModel> createOnlineJob(
    TranscriptionJobRequest request,
  );

  Stream<TranscriptionJobModel> watchJob(String jobId);

  Future<void> cancelJob(String jobId, {String? reason});
}

@LazySingleton(as: TranscriptionJobRemoteDataSource)
class TranscriptionJobRemoteDataSourceImpl
    implements TranscriptionJobRemoteDataSource {
  TranscriptionJobRemoteDataSourceImpl(
    this._firestore,
    this._storage,
  );

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _jobsCollection =>
      _firestore.collection('transcription_jobs');

  @override
  Future<TranscriptionJobModel> createOnlineJob(
    TranscriptionJobRequest request,
  ) async {
    final file = File(request.localFilePath);
    if (!file.existsSync()) {
      throw const LocalFailure(message: 'Audio file not found on device');
    }

    final jobId = _uuid.v4();
    final fileName = request.displayName ?? p.basename(file.path);
    final storagePath = 'transcription_jobs/$jobId/$fileName';
    final docRef = _jobsCollection.doc(jobId);

    await docRef.set({
      'mode': request.mode.name,
      'status': TranscriptionJobStatus.uploading.name,
      'audioStoragePath': storagePath,
      'durationSeconds': request.duration.inSeconds,
      'approxSizeBytes': request.fileSizeBytes,
      'metadata': request.metadata,
      'progress': 0.0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final fileMetadata = SettableMetadata(
      contentType: _guessContentType(file.path),
      customMetadata: {
        'jobId': jobId,
        'durationSeconds': '${request.duration.inSeconds}',
      },
    );

    await _storage.ref(storagePath).putFile(file, fileMetadata);

    await docRef.update({
      'status': TranscriptionJobStatus.processing.name,
      'uploadCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'progress': 0.05,
    });

    final snapshot = await docRef.get();
    return TranscriptionJobModel.fromSnapshot(snapshot);
  }

  @override
  Stream<TranscriptionJobModel> watchJob(String jobId) {
    return _jobsCollection.doc(jobId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw const ServerFailure(message: 'Job not found');
      }
      return TranscriptionJobModel.fromSnapshot(snapshot);
    });
  }

  @override
  Future<void> cancelJob(String jobId, {String? reason}) {
    return _jobsCollection.doc(jobId).update({
      'status': TranscriptionJobStatus.error.name,
      'errorCode': 'client_cancelled',
      'errorMessage': reason ?? 'Cancelled by user',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _guessContentType(String path) {
    final extension = p.extension(path).toLowerCase();
    switch (extension) {
      case '.m4a':
      case '.aac':
        return 'audio/aac';
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
      default:
        return 'audio/wav';
    }
  }
}

