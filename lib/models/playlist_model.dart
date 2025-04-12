import 'package:uuid/uuid.dart';

class Playlist {
  String id;
  String name;
  String style;
  String? imagePath; // Path to the stored image file

  Playlist({
    required this.id,
    required this.name,
    required this.style,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'style': style,
      'imagePath': imagePath,
    };
  }

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'],
      name: map['name'],
      style: map['style'],
      imagePath: map['imagePath'],
    );
  }
}