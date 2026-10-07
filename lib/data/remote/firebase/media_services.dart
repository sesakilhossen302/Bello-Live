import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'profile_services.dart';

class MediaService {
  static final _storage = FirebaseStorage.instance;

  // Compress and upload image
  static Future<String?> compressAndUploadImage(
    File imageFile, {
    String folder = 'social',
  }) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress image
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/compressed_$fileName';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        targetPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      final File fileToUpload = compressedFile != null
          ? File(compressedFile.path)
          : imageFile;

      // Upload to custom API
      final uri = Uri.parse('https://api.sdlive.fun/api/upload');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(
          await http.MultipartFile.fromPath('image', fileToUpload.path),
        );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      String downloadUrl = '';
      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        final jsonData = jsonDecode(responseBody) as Map<String, dynamic>;
        if (jsonData['success'] == true && jsonData['url'] != null) {
          downloadUrl = jsonData['url'];
        } else {
          throw Exception('API returned success=false');
        }
      } else {
        throw Exception(
          'API failed with status ${streamedResponse.statusCode}',
        );
      }

      // Clean up temp file
      if (compressedFile != null) {
        await File(compressedFile.path).delete();
      }

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // Compress and upload video (max 15 seconds)
  static Future<Map<String, dynamic>?> compressAndUploadVideo(
    File videoFile,
  ) async {
    try {
      final String userId = FirebaseAuth.instance.currentUser!.uid;
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';

      // Compress video
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (mediaInfo == null || mediaInfo.file == null) {
        throw Exception('Video compression failed');
      }

      // Check duration (max 15 seconds)
      final duration = mediaInfo.duration?.toInt() ?? 0;
      if (duration > 15000) {
        // 15 seconds in milliseconds
        throw Exception('Video must be 15 seconds or less');
      }

      // Upload compressed video
      final ref = _storage.ref().child('chat_media/$userId/videos/$fileName');
      final uploadTask = ref.putFile(mediaInfo.file!);

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Generate and upload thumbnail
      String? thumbnailUrl;
      final thumbnail = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: 50,
      );

      final thumbRef = _storage.ref().child(
        'chat_media/$userId/thumbnails/thumb_$fileName.jpg',
      );
      final thumbSnapshot = await thumbRef.putFile(thumbnail);
      thumbnailUrl = await thumbSnapshot.ref.getDownloadURL();

      // Clean up
      await VideoCompress.deleteAllCache();

      return {
        'url': downloadUrl,
        'duration': (duration / 1000).round(), // Convert to seconds
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      debugPrint('Error uploading video: $e');
      await VideoCompress.deleteAllCache();
      return null;
    }
  }

  // Upload voice recording
  static Future<String?> uploadVoiceRecording(File audioFile) async {
    try {
      final String userId = FirebaseAuth.instance.currentUser!.uid;
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';

      final ref = _storage.ref().child('chat_media/$userId/voice/$fileName');
      final uploadTask = ref.putFile(audioFile);

      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading voice: $e');
      return null;
    }
  }

  // Get file size in MB
  static double getFileSizeInMB(File file) {
    final bytes = file.lengthSync();
    return bytes / (1024 * 1024);
  }
}
