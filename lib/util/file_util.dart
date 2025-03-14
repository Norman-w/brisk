import 'dart:async';
import 'dart:io';

import 'package:brisk/util/file_extensions.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

import '../constants/file_type.dart';
import '../model/isolate/isolate_args_pair.dart';
import 'settings_cache.dart';

class FileUtil {
  static final versionedFileRegex = RegExp('.*_\d*');
  static late Directory defaultTempFileDir;
  static late Directory defaultSaveDir;

  static Future<Directory> setDefaultTempDir() {
    Completer<Directory> completer = Completer();
    getTemporaryDirectory().then((dir) {
      final tmpSubDir = join(dir.path, 'Brisk');
      defaultTempFileDir = Directory(tmpSubDir);
      defaultTempFileDir.createSync(recursive: true);
      completer.complete(defaultTempFileDir);
    });
    return completer.future;
  }

  static Future<Directory> setDefaultSaveDir() {
    Completer<Directory> completer = Completer();
    getDownloadsDirectory().then((dir) {
      defaultSaveDir = Directory(join(dir!.path, 'Brisk'));
      /// TODO FIX NULL CHECK
      defaultSaveDir.createSync(recursive: true);
      completer.complete(defaultSaveDir);
    });
    return completer.future;
  }

  static String getFilePath(String fileName, {Directory? baseSaveDir}) {
    final saveDir = baseSaveDir ?? SettingsCache.saveDir;
    if (!saveDir.existsSync()) {
      saveDir.createSync();
      _createSubDirectories(saveDir.path);
    }

    final subDir = _fileTypeToFolderName(detectFileType(fileName));
    var filePath = join(saveDir.path, subDir, fileName);
    final subdirFullPath = join(saveDir.path, subDir);
    var file = File(filePath);
    final extension = fileName.endsWith("tar.gz")
        ? "tar.gz"
        : fileName.substring(fileName.lastIndexOf('.') + 1);
    int version = 1;

    while (file.existsSync()) {
      var rawName = getRawFileName(fileName);
      if (versionedFileRegex.hasMatch(rawName)) {
        rawName = rawName.substring(0, rawName.lastIndexOf('_'));
      }
      ++version;
      fileName = '${rawName}_$version.$extension';
      file = File(join(subdirFullPath, fileName));
    }

    return join(saveDir.path, subDir, fileName);
  }

  static String getRawFileName(String fileName) {
    return fileName.substring(
        0,
        fileName.endsWith(".tar.gz")
            ? fileName.lastIndexOf('.') - 4
            : fileName.lastIndexOf('.'));
  }

  static void _createSubDirectories(String path) async {
    final dirs = [
      Directory(join(path, 'Music')),
      Directory(join(path, 'Compressed')),
      Directory(join(path, 'Videos')),
      Directory(join(path, 'Programs')),
      Directory(join(path, 'Documents')),
      Directory(join(path, 'Other'))
    ];
    for (var dir in dirs) {
      await dir.create();
    }
  }

  /// Detects the [DLFileType] based on the file extension.
  /// TODO : Read from setting cache
  static DLFileType detectFileType(String fileName) {
    final type = extension(fileName.toLowerCase()).replaceAll(".", "");
    if (FileExtensions.document.contains(type)) {
      return DLFileType.documents;
    } else if (FileExtensions.program.contains(type)) {
      return DLFileType.program;
    } else if (FileExtensions.compressed.contains(type) ||
        fileName.endsWith("tar.gz")) {
      return DLFileType.compressed;
    } else if (FileExtensions.music.contains(type)) {
      return DLFileType.music;
    } else if (FileExtensions.video.contains(type)) {
      return DLFileType.video;
    } else {
      return DLFileType.other;
    }
  }

  static String _fileTypeToFolderName(DLFileType fileType) {
    if (fileType == DLFileType.video) {
      return 'Videos';
    } else if (fileType == DLFileType.music) {
      return 'Music';
    } else if (fileType == DLFileType.program) {
      return 'Programs';
    } else if (fileType == DLFileType.documents) {
      return 'Documents';
    } else if (fileType == DLFileType.compressed) {
      return 'Compressed';
    } else {
      return 'Other';
    }
  }

  /// Iterates through all written file parts and adds their byte length.
  /// Returns the total byte length which is used to display part write progress
  /// in the UI and also to set the proper download headers for a resume download request.
  static int calculateReceivedBytesSync(Directory dir) {
    int totalLength = 0;
    for (var file in dir.listSync(recursive: true)) {
      totalLength += (file as File).lengthSync();
    }
    return totalLength;
  }

  /// Simply calls [calculateReceivedBytesSync] but is intended to be used by an isolate
  static void calculateReceivedBytesIsolated(IsolateArgsPair<Directory> args) {
    args.sendPort.send(calculateReceivedBytesSync(args.obj));
  }

  static String resolveFileTypeIconPath(DLFileType fileType) {
    if (fileType == DLFileType.music) {
      return 'assets/icons/music.svg';
    } else if (fileType == DLFileType.video) {
      return 'assets/icons/video_2.svg';
    } else if (fileType == DLFileType.compressed) {
      return 'assets/icons/archive.svg';
    } else if (fileType == DLFileType.documents) {
      return 'assets/icons/document.svg';
    } else if (fileType == DLFileType.program) {
      return 'assets/icons/program.svg';
    } else {
      return 'assets/icons/file.svg';
    }
  }

  static Color resolveFileTypeIconColor(DLFileType fileType) {
    if (fileType == DLFileType.music) {
      return Colors.cyanAccent;
    } else if (fileType == DLFileType.video) {
      return Colors.pinkAccent;
    } else if (fileType == DLFileType.compressed) {
      return Colors.blue;
    } else if (fileType == DLFileType.documents) {
      return Colors.orangeAccent;
    } else if (fileType == DLFileType.program) {
      return const Color.fromRGBO(163, 74, 40, 1);
    } else {
      return Colors.grey;
    }
  }

  static void deleteDownloadTempDirectory(int id) {
    final path = join(defaultTempFileDir.path, id.toString());
    final dir = Directory(path);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  }

  static int sortByFileName(FileSystemEntity a, FileSystemEntity b) {
    return fileNameToInt(a).compareTo(fileNameToInt(b));
  }

  static int fileNameToInt(FileSystemEntity file) {
    return int.parse(basename(file.path).toString());
  }

  static bool checkFileDuplication(String fileName) {
    final subDir = _fileTypeToFolderName(detectFileType(fileName));
    final filePath = join(SettingsCache.saveDir.path, subDir, fileName);
    return File(filePath).existsSync();
  }
}
