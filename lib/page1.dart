import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

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

class Page1 extends StatefulWidget {
  final String? playlistUuid;



  const Page1({Key? key, this.playlistUuid}) : super(key: key);

  @override
  State<Page1> createState() => _Page1State();
}

class _Page1State extends State<Page1> with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  bool isPlaying = false;
  final AudioPlayer audioPlayer = AudioPlayer();
  List<Music> songs = [];
  String? currentPlaylistUuid;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    currentPlaylistUuid = widget.playlistUuid;
    loadSongsForPlaylist(currentPlaylistUuid);
    audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          isPlaying = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> loadSongsForPlaylist(String? playlistUuid) async {
    if (playlistUuid == null) {
      setState(() {
        songs = [];
      });
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString('playlist_songs_$playlistUuid');

      if (storedJson != null && storedJson.isNotEmpty) {
        final List<dynamic> decodedList = jsonDecode(storedJson);
        final List<Music> loadedSongs =
        decodedList.map((item) => Music.fromJson(item)).toList();
        setState(() {
          songs = loadedSongs;
        });
      } else {
        setState(() {
          songs = []; // No mock data, just an empty list
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading songs')),
        );
      }
    }
  }

  Future<void> saveSongsForPlaylist() async {
    if (currentPlaylistUuid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData =
      jsonEncode(songs.map((song) => song.toJson()).toList());
      await prefs.setString('playlist_songs_$currentPlaylistUuid', encodedData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving songs')),
        );
      }
    }
  }

  Future<void> playPause() async {
    if (songs.isEmpty || selectedIndex >= songs.length || selectedIndex < 0) {
      return;
    }

    final song = songs[selectedIndex];
    final sourcePath = song.filemusicmp3;
    Source? source;

    try {
      final file = File(sourcePath);
      if (await file.exists()) {
        source = DeviceFileSource(sourcePath);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: File not found for "${song.nameMusic}"')),
          );
        }
        return;
      }

      if (isPlaying) {
        await audioPlayer.pause();
      } else {
        await audioPlayer.play(source);
      }

      if (mounted) {
        setState(() {
          isPlaying = !isPlaying;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing "${song.nameMusic}"')),
        );
        setState(() {
          isPlaying = false;
        });
      }
    }
  }

  Future<void> playSelectedSong(int index) async {
    if (index >= songs.length || index < 0) return;

    await audioPlayer.stop();
    if (mounted) {
      setState(() {
        selectedIndex = index;
        isPlaying = false;
      });
    }
    playPause();
  }

  Future<void> playNextSong() async {
    if (songs.isEmpty) return;
    final newIndex = (selectedIndex + 1) % songs.length;
    playSelectedSong(newIndex);
  }

  Future<void> playPreviousSong() async {
    if (songs.isEmpty) return;
    final newIndex = (selectedIndex - 1 + songs.length) % songs.length;
    playSelectedSong(newIndex);
  }


  Future<void> importMp3AndImage() async {
    if (currentPlaylistUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No playlist selected')),
      );
      return;
    }

    String songName = '';
    String artistName = '';
    String? mp3Path;
    String? imagePath;
    String mp3FileName = '';
    String imageFileName = '';

    final songNameController = TextEditingController();
    final artistNameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Add Music', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: songNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Song Name',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) => songName = value,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: artistNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Artist Name',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (value) => artistName = value,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade800),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.music_note,
                            color: mp3Path != null ? Colors.blue : Colors.white),
                        title: Text(
                          mp3Path != null ? mp3FileName : 'Select MP3',
                          style: TextStyle(
                            color: mp3Path != null ? Colors.blue : Colors.white,
                          ),
                        ),
                        subtitle: mp3Path != null
                            ? Text('MP3 file selected',
                            style: TextStyle(color: Colors.grey[400]))
                            : null,
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.audio,
                            allowMultiple: false,
                          );
                          if (result != null) {
                            setLocalState(() {
                              mp3Path = result.files.single.path;
                              mp3FileName = result.files.single.name;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade800),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.image,
                            color: imagePath != null ? Colors.green : Colors.white),
                        title: Text(
                          imagePath != null ? imageFileName : 'Select Image',
                          style: TextStyle(
                            color: imagePath != null ? Colors.green : Colors.white,
                          ),
                        ),
                        subtitle: imagePath != null
                            ? Text('Image file selected',
                            style: TextStyle(color: Colors.grey[400]))
                            : null,
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.image,
                            allowMultiple: false,
                          );
                          if (result != null) {
                            setLocalState(() {
                              imagePath = result.files.single.path;
                              imageFileName = result.files.single.name;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    songNameController.dispose();
                    artistNameController.dispose();
                    Navigator.pop(dialogContext);
                  },
                ),
                TextButton(
                  child: const Text('Import', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    if (mp3Path == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select an MP3 file')),
                      );
                      return;
                    }

                    songName = songNameController.text;
                    artistName = artistNameController.text;

                    if (songName.isEmpty || artistName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter song and artist names')),
                      );
                      return;
                    }

                    songNameController.dispose();
                    artistNameController.dispose();
                    Navigator.pop(dialogContext);
                    await _addSongWithDetails(songName, artistName, mp3Path!, imagePath);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }


  Future<void> _addSongWithDetails(String songName, String artistName, String mp3Path, String? imagePath) async {
    try {
      final tempPlayer = AudioPlayer();
      await tempPlayer.setSource(DeviceFileSource(mp3Path));
      final duration = await tempPlayer.getDuration() ?? const Duration(seconds: 0);
      await tempPlayer.dispose();

      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      final timeMusic = '$minutes:${seconds.toString().padLeft(2, '0')}';

      final newSong = Music(
        uuidMusic: const Uuid().v4(),
        uuidPlaylist: currentPlaylistUuid!,
        nameMusic: songName,
        nameAuthor: artistName,
        timeMusic: timeMusic,
        filemusicmp3: mp3Path,
        imagePath: imagePath,
      );

      if (songs.any((song) => song.filemusicmp3 == newSong.filemusicmp3)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This song already exists in the playlist')),
          );
        }
        return;
      }

      setState(() {
        songs.add(newSong);
      });

      await saveSongsForPlaylist();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$songName" successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error importing song')),
        );
      }
    }
  }

  Future<void> importBoth() async {
    // First import MP3
    final Music? newSong = await importMp3(returnSong: true);
    if (newSong != null) {
      // Then import image for this song
      importImage(forSong: newSong);
    }
  }

  Future<Music?> importMp3({bool returnSong = false}) async {
    if (currentPlaylistUuid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: No playlist selected')),
      );
      return null;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final filename = file.path.split('/').last;
        final title = filename.contains('.')
            ? filename.substring(0, filename.lastIndexOf('.'))
            : filename;

        // สร้าง AudioPlayer ชั่วคราวเพื่อเช็คความยาวเพลง
        final tempPlayer = AudioPlayer();
        await tempPlayer.setSource(DeviceFileSource(file.path));
        final duration = await tempPlayer.getDuration() ?? const Duration(seconds: 0);
        await tempPlayer.dispose();

        // แปลง duration เป็นรูปแบบ mm:ss
        final minutes = duration.inMinutes;
        final seconds = duration.inSeconds.remainder(60);
        final timeMusic = '$minutes:${seconds.toString().padLeft(2, '0')}';

        final uuidMusic = const Uuid().v4();

        final newSong = Music(
          uuidMusic: uuidMusic,
          uuidPlaylist: currentPlaylistUuid!,
          nameMusic: title,
          nameAuthor: 'Unknown Artist',
          timeMusic: timeMusic, // ใช้เวลาจริงของเพลง
          filemusicmp3: file.path,
        );

        if (songs.any((song) => song.filemusicmp3 == newSong.filemusicmp3)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This song already exists in the playlist')),
          );
          return null;
        }

        setState(() {
          songs.add(newSong);
        });

        await saveSongsForPlaylist();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "${newSong.nameMusic}" successfully')),
        );

        if (returnSong) {
          return newSong;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error importing MP3 file')),
      );
    }
    return null;
  }

  Future<void> importImage({Music? forSong}) async {
    Music? songToUpdate;

    if (forSong != null) {
      songToUpdate = forSong;
    } else if (songs.isNotEmpty) {
      // If no song provided, use the currently selected song
      if (selectedIndex >= 0 && selectedIndex < songs.length) {
        songToUpdate = songs[selectedIndex];
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a song first')),
        );
        return;
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No songs in playlist')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final imagePath = result.files.single.path!;

        // Find the song in the list
        int songIndex = songs.indexWhere((s) => s.uuidMusic == songToUpdate!.uuidMusic);
        if (songIndex != -1) {
          // Update the image path
          setState(() {
            songs[songIndex] = Music(
              uuidMusic: songToUpdate!.uuidMusic,
              uuidPlaylist: songToUpdate.uuidPlaylist,
              nameMusic: songToUpdate.nameMusic,
              nameAuthor: songToUpdate.nameAuthor,
              timeMusic: songToUpdate.timeMusic,
              filemusicmp3: songToUpdate.filemusicmp3,
              imagePath: imagePath,
            );
          });

          await saveSongsForPlaylist();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image added to "${songToUpdate.nameMusic}"')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error importing image')),
      );
    }
  }

  Future<void> deleteSong(int index) async {
    if (index >= songs.length || index < 0) return;

    final songToDelete = songs[index];
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
          content:
          Text('Are you sure you want to delete "${songToDelete.nameMusic}"?',
              style: const TextStyle(color: Colors.white)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ??
        false;

    if (confirmDelete) {
      if (isPlaying) {
        await audioPlayer.stop();
        isPlaying = false;
      }

      setState(() {
        songs.removeAt(index);

        // Fix: Properly handle deletion of the last or only song
        if (songs.isEmpty) {
          selectedIndex = -1; // No song selected
        } else if (selectedIndex >= songs.length) {
          // If we deleted the last song and it was selected, move selection up
          selectedIndex = songs.length - 1;
        }
        // Otherwise keep the current selectedIndex
      });

      await saveSongsForPlaylist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${songToDelete.nameMusic}"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSong = (songs.isNotEmpty &&
        selectedIndex < songs.length &&
        selectedIndex >= 0)
        ? songs[selectedIndex]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF214863),
      appBar: AppBar(
          backgroundColor: const Color(0xFF214863),
        toolbarHeight: 56,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // title: Column(
        //   crossAxisAlignment: CrossAxisAlignment.start,
        //   children: [
        //     Text(
        //       currentSong?.nameMusic ?? 'Music Player',
        //       style: TextStyle(fontSize: 16, color: Colors.white),
        //     ),
        //     Text(
        //       currentSong?.nameMusic ?? 'Music Player',
        //       style: const TextStyle(color: Colors.white, fontSize: 16),
        //     ),
        //   ],
        // ),
      ),
      body: Column(
        children: [
          if (currentSong != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF142E3E),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                      image: currentSong.imagePath != null
                          ? DecorationImage(
                        image: FileImage(File(currentSong.imagePath!)),
                        fit: BoxFit.cover,
                      )
                          : null,
                    ),
                    child: currentSong.imagePath == null
                        ? const Icon(Icons.music_note, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded( // Widget นี้จะขยายเพื่อดันปุ่มควบคุมไปทางขวา
                    child: Column( // Column นี้มีแค่ Text เท่านั้น
                      mainAxisSize: MainAxisSize.min, // ทำให้ Column สูงเท่าที่จำเป็น
                      crossAxisAlignment: CrossAxisAlignment.start, // จัดข้อความชิดซ้าย
                      children: [
                        // 1. ชื่อเพลง
                        Text(
                          // เพิ่มการตรวจสอบ null safety ให้ currentSong
                          currentSong?.nameMusic ?? 'Not Playing',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15, // ปรับขนาด Font ตามความเหมาะสม
                          ),
                          maxLines: 1, // จำกัด 1 บรรทัด
                          overflow: TextOverflow.ellipsis, // แสดง ... ถ้าข้อความยาวเกิน
                        ),
                        const SizedBox(height: 4), // ระยะห่างระหว่างชื่อเพลงกับศิลปิน
                        // 2. ชื่อศิลปิน
                        Text(
                          // เพิ่มการตรวจสอบ null safety
                          currentSong?.nameAuthor ?? '-',
                          style: TextStyle(
                            color: Colors.grey[400], // สีเทาสำหรับชื่อศิลปิน
                            fontSize: 13, // ปรับขนาด Font ตามความเหมาะสม
                          ),
                          maxLines: 1, // จำกัด 1 บรรทัด
                          overflow: TextOverflow.ellipsis, // แสดง ... ถ้าข้อความยาวเกิน
                        ),

                        // --- Row ที่มีปุ่มควบคุม ถูกลบออกจากตรงนี้ ---
                      ],
                    ),
                  ),

                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: playPause,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_next,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: playNextSong,
                      ),
                      // Text(
                      //   currentSong.timeMusic,
                      //   style: TextStyle(color: Colors.grey[400]),
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(top: 16),
            color: const Color(0xFF214863),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.white,
              tabs: const [
                Tab(text: 'UP NEXT'),
                Tab(text: 'LYRICS'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // UP NEXT tab
                songs.isEmpty
                    ? const Center(
                    child: Text('No songs in this playlist.',
                        style: TextStyle(color: Colors.white)))
                    : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final isCurrentSong = selectedIndex == index;

                    return Container(
                      color: isCurrentSong
                          ? const Color(0xFF2E6389)
                          : const Color(0xFF214863),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(4),
                                    image: song.imagePath != null
                                        ? DecorationImage(
                                      image: FileImage(File(song.imagePath!)),
                                      fit: BoxFit.cover,
                                    )
                                        : null,
                                  ),
                                  child: song.imagePath == null
                                      ? const Icon(Icons.music_note,
                                      color: Colors.white, size: 20)
                                      : null,
                                ),
                                if (isCurrentSong)
                                  const Icon(Icons.graphic_eq,
                                      color: Colors.white, size: 40),
                              ],
                            ),
                          ],
                        ),
                        title: Text(
                          song.nameMusic,
                          style: TextStyle(
                            color: isCurrentSong
                                ? Colors.white
                                : Colors.grey[300],
                            fontWeight: isCurrentSong
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: song.nameAuthor,
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              TextSpan(
                                text: ' • ${song.timeMusic}',
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => playSelectedSong(index),
                        trailing: IconButton(
                          icon: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 2,
                                margin: EdgeInsets.symmetric(vertical: 2),
                                color: Colors.grey,
                              ),
                              Container(
                                width: 20,
                                height: 2,
                                margin: EdgeInsets.symmetric(vertical: 2),
                                color: Colors.grey,
                              ),
                            ],
                          ),
                          onPressed: () => deleteSong(index),
                        ),

                      ),
                    );
                  },
                ),
                // LYRICS tab
                const Center(
                  child: Text(
                    'Lyrics not available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: importMp3AndImage,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}