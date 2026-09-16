import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main() async {
  final yt = YoutubeExplode();
  try {
    print('Searching...');
    final searchResults = await yt.search.search('NCS release');
    final video = searchResults.first;
    print('Found video: ${video.title}');
    
    final manifest = await yt.videos.streamsClient.getManifest(video.id);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
    final streamUrl = audioStreamInfo.url.toString();
    print('Stream URL: $streamUrl');
  } catch (e) {
    print('Error: $e');
  } finally {
    yt.close();
  }
}
