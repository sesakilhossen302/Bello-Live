import 'dart:io';

void main() {
  final file = File(r'e:\Office Projects\Smartlive app\smartlive\lib\ui\streaming\audio_room_page.dart');
  var content = file.readAsStringSync();
  
  // Replace single-line instances
  content = content.replaceAll(
    "RoomParticipant(userId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false)",
    "RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false)",
  );
  
  // Replace multi-line instance at line 743
  content = content.replaceAll(
    "RoomParticipant(\n                userId: '',\n                userName: '',\n                seatNo: -1,\n                isCoHost: false,\n                isMuted: true,\n              )",
    "RoomParticipant(\n                userId: '',\n                displayId: '',\n                userName: '',\n                seatNo: -1,\n                isCoHost: false,\n                isMuted: true,\n              )"
  );
  
  content = content.replaceAll(
    "RoomParticipant(userId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: true)",
    "RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: true)"
  );
  
  file.writeAsStringSync(content);
  print('Replaced missing displayId occurrences.');
}
