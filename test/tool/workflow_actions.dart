// How a workflow names a third-party action: by the full commit of a release tag, with the tag in a comment next to
// it, so that a tag moved to another commit cannot change what runs. Reading the workflow as YAML drops the comment,
// so these read its lines.

/// The `uses:` lines among [lines] that name an action outside actions/, trimmed.
List<String> thirdPartyUses(Iterable<String> lines) => [
  for (final line in lines)
    if (RegExp(r'uses:\s+(?!actions/)').hasMatch(line)) line.trim(),
];

/// A trimmed `uses:` line that names its action by a full commit, with the tag of that commit in a comment.
final fixedToCommit = RegExp(r'^(- )?uses: [\w-]+/[\w-]+@[0-9a-f]{40} # v\d+(\.\d+)*$');
