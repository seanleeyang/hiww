import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_exception.dart';
import '../features/uploads/data/uploads_repository.dart';

/// A form control that picks an image (camera or gallery), uploads it and
/// reports back the stored URL. [value] is that URL (or null when unset).
class ImagePickerField extends ConsumerStatefulWidget {
  const ImagePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Add a photo',
    this.circle = false,
    this.height = 160,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  /// Render as a round avatar picker instead of a wide banner.
  final bool circle;
  final double height;

  @override
  ConsumerState<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends ConsumerState<ImagePickerField> {
  final _picker = ImagePicker();
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      setState(() => _busy = true);
      final url = await ref.read(uploadsRepositoryProvider).uploadImage(file);
      if (!mounted) return;
      widget.onChanged(url);
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('Could not add that photo. Try another.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return widget.circle ? _buildCircle(context) : _buildBanner(context);
  }

  Widget _buildBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = widget.value != null;

    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: _busy ? null : _showMenu,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: widget.height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
            color: scheme.surfaceContainerHighest,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                CachedNetworkImage(imageUrl: widget.value!, fit: BoxFit.cover)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.label,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              if (hasImage)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _EditChip(onTap: _busy ? null : _showMenu),
                ),
              if (_busy) const _BusyOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = widget.value != null;

    return Center(
      child: Semantics(
        button: true,
        label: widget.label,
        child: InkWell(
          onTap: _busy ? null : _showMenu,
          customBorder: const CircleBorder(),
          child: Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundImage: hasImage
                    ? CachedNetworkImageProvider(widget.value!)
                    : null,
                child: hasImage
                    ? null
                    : Icon(
                        Icons.add_a_photo_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: scheme.primary,
                  child: Icon(
                    _busy ? Icons.hourglass_empty : Icons.edit,
                    size: 15,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Open the source sheet; a `null` result from a "Remove photo" tap clears
  /// the value, a plain dismiss leaves it unchanged.
  Future<void> _showMenu() async {
    final choice = await showModalBottomSheet<_SheetChoice>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () =>
                    Navigator.pop(context, const _SheetChoice.camera()),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, const _SheetChoice.gallery()),
            ),
            if (widget.value != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove photo'),
                onTap: () =>
                    Navigator.pop(context, const _SheetChoice.remove()),
              ),
          ],
        ),
      ),
    );
    switch (choice?.kind) {
      case _ChoiceKind.camera:
        await _pick(ImageSource.camera);
      case _ChoiceKind.gallery:
        await _pick(ImageSource.gallery);
      case _ChoiceKind.remove:
        widget.onChanged(null);
      case null:
        break;
    }
  }
}

enum _ChoiceKind { camera, gallery, remove }

class _SheetChoice {
  const _SheetChoice._(this.kind);
  const _SheetChoice.camera() : this._(_ChoiceKind.camera);
  const _SheetChoice.gallery() : this._(_ChoiceKind.gallery);
  const _SheetChoice.remove() : this._(_ChoiceKind.remove);
  final _ChoiceKind kind;
}

class _EditChip extends StatelessWidget {
  const _EditChip({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface.withValues(alpha: 0.92),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.edit, size: 15),
              const SizedBox(width: 6),
              Text('Change', style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.35),
      child: const Center(
        child: SizedBox(
          height: 26,
          width: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
