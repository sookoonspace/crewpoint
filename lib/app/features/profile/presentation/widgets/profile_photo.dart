import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:crewpoint_app/app/core/design/components/components.dart';
import 'package:crewpoint_app/app/core/design/tokens/tokens.dart';

/// A person's photo in a circle: [bytes] just picked, else the photo at
/// [url], else their initials, which also stand in while it loads or when
/// it fails.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({
    super.key,
    required this.url,
    required this.name,
    this.bytes,
  });

  final String? url;
  final String name;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final side = context.cp.sizes.avatarLg;
    final initials = CpAvatar(name: name, size: CpAvatarSize.large);
    final picked = bytes;
    final photo = url;
    final Widget image;
    if (picked != null) {
      image = Image.memory(
        picked,
        width: side,
        height: side,
        fit: BoxFit.cover,
        semanticLabel: name,
      );
    } else if (photo != null && photo.isNotEmpty) {
      image = Image.network(
        photo,
        width: side,
        height: side,
        fit: BoxFit.cover,
        semanticLabel: name,
        errorBuilder: (_, _, _) => initials,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : initials,
      );
    } else {
      return initials;
    }
    return ClipOval(child: image);
  }
}
