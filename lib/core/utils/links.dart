const String baseUrl = 'https://pub-a84b75c9c456460f9aadb5a9bc90b348.r2.dev/';

String getFullUrl(String url) {
  // Check if URL already has a protocol (http:// or https://)
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  // Otherwise, prepend the base URL
  return '$baseUrl$url';
}
