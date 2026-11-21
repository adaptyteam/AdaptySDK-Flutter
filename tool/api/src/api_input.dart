import 'dart:io';

/// The folder name of the copy that `dart_apitool` reads: the name of the plugin.
///
/// Flutter 3.50 copies a plugin whose folder has another name into `build/ios/SourcePackages` of the folder it runs
/// in on every `pub get` that resolves the example, and `dart_apitool` runs `pub get` on the folder it reads. On the
/// repository root the copy then lands inside the root and takes the copies of the earlier runs with it.
const apiInputName = 'adapty_flutter';

/// What the copy holds: the files and folders of the package that its public API depends on. The `ios` and
/// `android` folders give the API its platform constraints.
const _required = ['pubspec.yaml', 'lib'];
const _optional = ['pubspec.lock', 'analysis_options.yaml', 'ios', 'android'];

/// Folders left out at any depth of a copied folder: build output and tool caches.
const _skipped = {'build', '.gradle', '.cxx', '.build', '.dart_tool'};

/// Copies what `dart_apitool` needs to read the public API of the package at [root] into a new folder
/// `<parent>/adapty_flutter` and returns its path.
///
/// The copy holds `pubspec.yaml`, `pubspec.lock` and `analysis_options.yaml` when the package has them, and the
/// `lib`, `ios` and `android` folders without `build`, `.gradle`, `.cxx`, `.build` and `.dart_tool` folders. A link
/// is copied as a link to the same target. Throws a [FileSystemException] when the package has no `pubspec.yaml` or
/// `lib` folder, or when the copy already exists.
String copyApiInput(String root, String parent) {
  for (final name in _required) {
    final path = '$root/$name';
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      throw FileSystemException('the package has no $name', path);
    }
  }
  final copy = '$parent/$apiInputName';
  if (FileSystemEntity.typeSync(copy, followLinks: false) != FileSystemEntityType.notFound) {
    throw FileSystemException('the copy of the package already exists', copy);
  }
  Directory(copy).createSync();
  for (final name in [..._required, ..._optional]) {
    final path = '$root/$name';
    if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound) {
      _copy(path, '$copy/$name');
    }
  }
  return copy;
}

void _copy(String from, String to) {
  switch (FileSystemEntity.typeSync(from, followLinks: false)) {
    case FileSystemEntityType.link:
      Link(to).createSync(Link(from).targetSync());
    case FileSystemEntityType.directory:
      Directory(to).createSync();
      for (final entity in Directory(from).listSync(followLinks: false)) {
        final name = entity.path.substring(from.length + 1);
        if (entity is Directory && _skipped.contains(name)) continue;
        _copy(entity.path, '$to/$name');
      }
    default:
      File(from).copySync(to);
  }
}
