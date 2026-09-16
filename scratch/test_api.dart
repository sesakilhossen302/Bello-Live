import 'package:livekit_client/livekit_client.dart';

void test(LocalVideoTrack track) async {
  Hardware.instance;
  try {
    Helper.switchCamera(track.mediaStreamTrack);
  } catch (e) {}
}
