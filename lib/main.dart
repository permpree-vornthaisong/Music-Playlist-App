import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:MusicPlaylistApp/page1.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

// Main app
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Playlist App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const MyPlaylistScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Playlist model
class Playlist {
  final String uuid;
  final String nameplaylist;
  final String namestyle;
  final String? imagePath;

  Playlist({
    required this.uuid,
    required this.nameplaylist,
    required this.namestyle,
    this.imagePath,
  });

  Map<String, dynamic> toJson() => {
    'uuid': uuid,
    'nameplaylist': nameplaylist,
    'namestyle': namestyle,
    'imagePath': imagePath,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    uuid: json['uuid'],
    nameplaylist: json['nameplaylist'],
    namestyle: json['namestyle'],
    imagePath: json['imagePath'],
  );
}

// Music model
class Music {
  final String uuidMusic;
  final String uuidPlaylist;
  final String nameMusic;
  final String nameAuthor;
  final String timeMusic;
  final String filemusicmp3;
  String? imagePath;

  Music({
    required this.uuidMusic,
    required this.uuidPlaylist,
    required this.nameMusic,
    required this.nameAuthor,
    required this.timeMusic,
    required this.filemusicmp3,
    this.imagePath,
  });

  factory Music.fromJson(Map<String, dynamic> json) {
    return Music(
      uuidMusic: json['uuidMusic'] ?? '',
      uuidPlaylist: json['uuidPlaylist'] ?? '',
      nameMusic: json['nameMusic'] ?? '',
      nameAuthor: json['nameAuthor'] ?? '',
      timeMusic: json['timeMusic'] ?? '',
      filemusicmp3: json['filemusicmp3'] ?? '',
      imagePath: json['imagePath'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuidMusic': uuidMusic,
      'uuidPlaylist': uuidPlaylist,
      'nameMusic': nameMusic,
      'nameAuthor': nameAuthor,
      'timeMusic': timeMusic,
      'filemusicmp3': filemusicmp3,
      'imagePath': imagePath,
    };
  }
}

// Main Playlist Screen
class MyPlaylistScreen extends StatefulWidget {
  const MyPlaylistScreen({super.key});

  @override
  State<MyPlaylistScreen> createState() => _MyPlaylistScreenState();
}

class _MyPlaylistScreenState extends State<MyPlaylistScreen> {
  List<Playlist> playlists = [];
  File? selectedImage;

  // --- Audio playback states ---
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingPlaylistUuid;
  List<Music> _currentPlaylistSongs = [];
  int _currentSongIndex = 0;
  bool _isPlaying = false;
  PlayerState _playerState = PlayerState.stopped;

  // --- Track the current position and duration ---
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late final StreamSubscription<Duration> _positionStreamSubscription;
  late final StreamSubscription<Duration> _durationStreamSubscription;

  @override
  void initState() {
    super.initState();
    loadPlaylists();

    // --- Position update listener ---
    _positionStreamSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    // --- Duration update listener ---
    _durationStreamSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    // --- Player state listener ---
    _audioPlayer.onPlayerComplete.listen((event) {
      // When current song finishes, play the next one
      if (_currentPlaylistSongs.isNotEmpty && _currentSongIndex < _currentPlaylistSongs.length - 1) {
        _currentSongIndex++;
        _playCurrentSong();
      } else {
        // Finished playlist
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _currentlyPlayingPlaylistUuid = null;
            _currentSongIndex = 0;
            _currentPlaylistSongs = [];
            _playerState = PlayerState.stopped;
            _currentPosition = Duration.zero;
            _totalDuration = Duration.zero;
          });
        }
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          // Update isPlaying based on player state
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription.cancel();
    _durationStreamSubscription.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('my_playlists') ?? [];
    final loaded = data.map((item) => Playlist.fromJson(jsonDecode(item))).toList();
    if (mounted) {
      setState(() {
        playlists = loaded;
      });
    }
  }

  Future<void> savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = playlists.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('my_playlists', data);
  }

  Future<void> addPlaylist(
      String name,
      String style, [
        String? imagePath,
      ]) async {
    final newPlaylist = Playlist(
      uuid: const Uuid().v4(),
      nameplaylist: name,
      namestyle: style,
      imagePath: imagePath,
    );
    setState(() {
      playlists.add(newPlaylist);
    });
    await savePlaylists();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(pickedFile.path);
      final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');

      selectedImage = savedImage;
    }
  }

  Future<void> _showAddPlaylistDialog() async {
    final formKey = GlobalKey<FormState>();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController styleController = TextEditingController();
    File? _dialogSelectedImage;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (
              BuildContext innerContext,
              void Function(void Function()) setInnerState,
              ) {
            // Dialog's image picking function
            Future<void> pickImageForDialog() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile != null) {
                final appDir = await getApplicationDocumentsDirectory();
                final fileName = path.basename(pickedFile.path);
                final savedImage = await File(pickedFile.path).copy('${appDir.path}/$fileName');
                setInnerState(() {
                  _dialogSelectedImage = savedImage;
                });
              }
            }

            return AlertDialog(
              title: const Text('Add New Playlist'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Playlist Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Please enter playlist name'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: styleController,
                        decoration: const InputDecoration(
                          labelText: 'Style / Genre *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Please enter playlist style'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        icon: const Icon(Icons.image),
                        label: const Text('Select Image'),
                        onPressed: pickImageForDialog,
                      ),
                      if (_dialogSelectedImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Image.file(_dialogSelectedImage!, height: 100),
                        ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(innerContext).pop();
                  },
                ),
                ElevatedButton(
                  child: const Text('Add Playlist'),
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      final name = nameController.text.trim();
                      final style = styleController.text.trim();
                      final imagePath = _dialogSelectedImage?.path;

                      Navigator.of(innerContext).pop();
                      addPlaylist(name, style, imagePath);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
    // Clear main selectedImage after dialog closes
    setState(() {
      selectedImage = null;
    });
  }

  // --- Load songs for a playlist ---
  Future<List<Music>> _loadSongsForPlaylist(String playlistUuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString('playlist_songs_$playlistUuid');

      if (storedJson != null && storedJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(storedJson);
        final List<Music> loadedSongs =
        decodedList.map((item) => Music.fromJson(item)).toList();
        return loadedSongs;
      } else {
        return [];
      }
    } catch (e) {
      print("Error loading songs for playlist $playlistUuid: $e");
      return [];
    }
  }

  // --- Toggle playlist playback ---
  Future<void> _togglePlaylistPlayback(Playlist playlist) async {
    final playlistUuid = playlist.uuid;

    // Case 1: The playlist is already playing - toggle pause/resume
    if (_currentlyPlayingPlaylistUuid == playlistUuid) {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
    }
    // Case 2: Play a new playlist
    else {
      // Stop current playback
      await _audioPlayer.stop();

      // Load songs for the new playlist
      final songs = await _loadSongsForPlaylist(playlistUuid);

      if (songs.isEmpty) {
        // Show message if playlist is empty
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playlist "${playlist.nameplaylist}" is empty.')),
          );
        }
        // Reset playback state
        if (mounted) {
          setState(() {
            _currentlyPlayingPlaylistUuid = null;
            _currentPlaylistSongs = [];
            _currentSongIndex = 0;
            _isPlaying = false;
            _playerState = PlayerState.stopped;
            _currentPosition = Duration.zero;
            _totalDuration = Duration.zero;
          });
        }
        return;
      }

      // Set state for the new playlist
      if (mounted) {
        setState(() {
          _currentlyPlayingPlaylistUuid = playlistUuid;
          _currentPlaylistSongs = songs;
          _currentSongIndex = 0;
          _isPlaying = false;
        });
      }

      // Start playing the first song
      await _playCurrentSong();
    }
  }

  // --- Play the current song in the queue ---
  Future<void> _playCurrentSong() async {
    if (_currentPlaylistSongs.isEmpty || _currentSongIndex >= _currentPlaylistSongs.length) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPlaylistUuid = null;
          _playerState = PlayerState.stopped;
          _currentPosition = Duration.zero;
          _totalDuration = Duration.zero;
        });
      }
      return;
    }

    // Reset position when starting a new song
    if (mounted) {
      setState(() {
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
      });
    }

    final songToPlay = _currentPlaylistSongs[_currentSongIndex];
    final sourcePath = songToPlay.filemusicmp3;
    Source? source;

    try {
      // Check if it's an asset or a file
      if (sourcePath.startsWith('sounds/')) {
        source = AssetSource(sourcePath);
      } else {
        final file = File(sourcePath);
        if (await file.exists()) {
          source = DeviceFileSource(sourcePath);
        } else {
          print('Error: File not found for "${songToPlay.nameMusic}": $sourcePath');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: File not found for "${songToPlay.nameMusic}"')),
            );
          }

          // Play next song if current file is not found
          if (_currentSongIndex < _currentPlaylistSongs.length - 1) {
            _currentSongIndex++;
            _playCurrentSong();
          } else {
            if (mounted) {
              setState(() {
                _isPlaying = false;
                _currentlyPlayingPlaylistUuid = null;
                _playerState = PlayerState.stopped;
                _currentPosition = Duration.zero;
                _totalDuration = Duration.zero;
              });
            }
          }
          return;
        }
      }

      // Start playing the song
      await _audioPlayer.play(source);

      // Show info about the currently playing song
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Now playing: ${songToPlay.nameMusic} by ${songToPlay.nameAuthor}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      print('Error playing "${songToPlay.nameMusic}": $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing "${songToPlay.nameMusic}"')),
        );
        setState(() {
          _isPlaying = false;
          _currentlyPlayingPlaylistUuid = null;
          _playerState = PlayerState.stopped;
          _currentPosition = Duration.zero;
          _totalDuration = Duration.zero;
        });
      }
    }
  }

  // Format duration to display time
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  // Build mini player with progress bar
  Widget _buildMiniPlayer() {
    if (_currentPlaylistSongs.isEmpty || _currentSongIndex >= _currentPlaylistSongs.length) {
      return const SizedBox.shrink();
    }

    final currentSong = _currentPlaylistSongs[_currentSongIndex];
    final currentPlaylist = playlists.firstWhere(
            (p) => p.uuid == _currentlyPlayingPlaylistUuid,
        orElse: () => Playlist(uuid: '', nameplaylist: 'Unknown', namestyle: '')
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.grey[300],
                thumbColor: Theme.of(context).primaryColor,
              ),
              child: Slider(
                min: 0.0,
                max: _totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0,
                value: _currentPosition.inMilliseconds.toDouble().clamp(
                    0.0,
                    _totalDuration.inMilliseconds > 0 ? _totalDuration.inMilliseconds.toDouble() : 1.0
                ),
                onChanged: (value) {
                  setState(() {
                    _currentPosition = Duration(milliseconds: value.toInt());
                  });
                },
                onChangeEnd: (value) {
                  _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
          ),

          // Time indicators
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatDuration(_currentPosition),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
                Text(
                  formatDuration(_totalDuration),
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          ),

          // Song info and controls
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 4.0),
            child: Row(
              children: [
                // Playlist/Song image
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                    ),
                    child: currentSong.imagePath != null
                        ? Image.file(
                      File(currentSong.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.music_note, size: 24, color: Colors.grey),
                    )
                        : currentPlaylist.imagePath != null
                        ? Image.file(
                      File(currentPlaylist.imagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.music_note, size: 24, color: Colors.grey),
                    )
                        : const Icon(Icons.music_note, size: 24, color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),

                // Song title and playlist name
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.nameMusic,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${currentSong.nameAuthor} • ${currentPlaylist.nameplaylist}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Previous song button
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  iconSize: 24,
                  onPressed: _currentSongIndex > 0
                      ? () {
                    setState(() {
                      _currentSongIndex--;
                    });
                    _playCurrentSong();
                  }
                      : null,
                  color: _currentSongIndex > 0 ? Colors.black87 : Colors.grey[400],
                ),

                // Play/Pause button
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
                  iconSize: 36,
                  color: Theme.of(context).primaryColor,
                  onPressed: () {
                    if (_currentlyPlayingPlaylistUuid != null) {
                      final playlistToToggle = playlists.firstWhere(
                              (p) => p.uuid == _currentlyPlayingPlaylistUuid);
                      _togglePlaylistPlayback(playlistToToggle);
                    }
                  },
                ),

                // Next song button
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  iconSize: 24,
                  onPressed: _currentSongIndex < _currentPlaylistSongs.length - 1
                      ? () {
                    setState(() {
                      _currentSongIndex++;
                    });
                    _playCurrentSong();
                  }
                      : null,
                  color: _currentSongIndex < _currentPlaylistSongs.length - 1
                      ? Colors.black87
                      : Colors.grey[400],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Playlist', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromRGBO(250, 249, 255, 1),
        actions: [
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            _showAddPlaylistDialog();
            // print("Add button pressed!");
          },
        ),
      ],
        // actions: [
        //   ElevatedButton(
        //     onPressed: () {
        //       _showAddPlaylistDialog();
        //     },
        //     child: const Text("Click Me"),
        //   ),
        // ],
        // actions: [
        //   if (_isPlaying || _playerState == PlayerState.paused)
        //     IconButton(
        //       icon: const Icon(Icons.stop),
        //       tooltip: 'Stop Playback',
        //       onPressed: () async {
        //         await _audioPlayer.stop();
        //         if (mounted) {
        //           setState(() {
        //             _currentlyPlayingPlaylistUuid = null;
        //             _currentPlaylistSongs = [];
        //             _currentSongIndex = 0;
        //             _isPlaying = false;
        //             _playerState = PlayerState.stopped;
        //             _currentPosition = Duration.zero;
        //             _totalDuration = Duration.zero;
        //           });
        //         }
        //       },
        //     ),
        // ],
      ),
      body: Column(
        children: [
          Expanded(
            child: playlists.isEmpty
                ? const Center(child: Text('No playlists yet. Tap + to add one.'))
                : ListView.builder(
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final p = playlists[index];
                final bool isCurrentlyPlayingThisPlaylist = _currentlyPlayingPlaylistUuid == p.uuid;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: InkWell(
                    // In main.dart, modify the onTap handler in the ListView.builder:
                    // In main.dart, modify the onTap handler in the ListView.builder:
                    onTap: () {
                      // First stop the audio player
                      _audioPlayer.stop().then((_) {
                        if (!mounted) return;

                        // Reset all playback states
                        setState(() {
                          _currentlyPlayingPlaylistUuid = null;
                          _currentPlaylistSongs = [];
                          _currentSongIndex = 0;
                          _isPlaying = false;
                          _playerState = PlayerState.stopped;
                          _currentPosition = Duration.zero;
                          _totalDuration = Duration.zero;
                        });

                        // Then navigate to Page1
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => Page1(playlistUuid: p.uuid),
                          ),
                        );
                      });
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                            border: isCurrentlyPlayingThisPlaylist && _isPlaying
                                ? Border.all(color: Theme.of(context).primaryColor, width: 2)
                                : null,
                          ),
                          child: p.imagePath != null
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.file(
                              File(p.imagePath!),
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, size: 30, color: Colors.grey),
                            ),
                          )
                              : Icon(Icons.music_note, size: 30, color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nameplaylist,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                p.namestyle,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isCurrentlyPlayingThisPlaylist && _isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
                            color: isCurrentlyPlayingThisPlaylist && _isPlaying
                                ? Theme.of(context).primaryColor
                                : Colors.grey[700],
                            size: 30,
                          ),
                          tooltip: isCurrentlyPlayingThisPlaylist && _isPlaying ? 'Pause' : 'Play Playlist',
                          onPressed: () {
                            _togglePlaylistPlayback(p);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Show mini player with timeline when a song is playing or paused
          if (_currentlyPlayingPlaylistUuid != null && _currentPlaylistSongs.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom,
              ),
              child: _buildMiniPlayer(),
            ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: _showAddPlaylistDialog,
      //   tooltip: 'Add New Playlist',
      //   child: const Icon(Icons.add),
      // ),
    );
  }
}