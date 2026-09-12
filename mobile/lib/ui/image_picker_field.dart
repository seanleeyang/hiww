import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_exception.dart';
import '../features/uploads/data/uploads_repository.dart';
import '../l10n/app_localizations.dart';

/// A form control that picks an image (camera or gallery), uploads it and
/// reports back the stored URL. [value] is that URL (or null when unset).
class ImagePickerField extends ConsumerStatefulWidget {
  const ImagePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.circle = false,
    this.height = 160,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  /// Defaults to the localized "Add a photo" — pass a custom label only
  /// when this picker means something more specific in context.
  final String? label;

  /// Render as a round avatar picker instead of a wide banner.
  final bool circle;
  final double height;

  @override
  ConsumerState<ImagePickerField> createState() => _ImagePickerFieldState();
}

class _ImagePickerFieldState extends ConsumerState<ImagePickerField> {
  final _picker = ImagePicker();
  bool _busy = false;

  String _label(BuildContext context) => widget.label ?? AppLocalizations.of(context)!.fieldAddPhoto;

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      await _upload(file);
    } catch (_) {
      if (!mounted) return;
      _toast(AppLocalizations.of(context)!.errorAddPhotoFailed);
    }
  }

  /// The general file browser (Downloads, Files app, cloud drives) rather
  /// than just the Photos picker `_pick(ImageSource.gallery)` opens.
  Future<void> _pickFromFiles() async {
    try {
      final picked = await FilePicker.pickFile(type: FileType.image);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await _upload(XFile.fromData(bytes, name: picked.name));
    } catch (_) {
      if (!mounted) return;
      _toast(AppLocalizations.of(context)!.errorAddPhotoFailed);
    }
  }

  Future<void> _upload(XFile file) async {
    setState(() => _busy = true);
    try {
      final url = await ref.read(uploadsRepositoryProvider).uploadImage(file);
      if (!mounted) return;
      widget.onChanged(url);
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      if (!mounted) return;
      _toast(AppLocalizations.of(context)!.errorAddPhotoFailed);
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
    final label = _label(context);

    return Semantics(
      button: true,
      label: label,
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
                      label,
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
        label: _label(context),
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

  /// Centered dialog (not a bottom sheet — easier to reach than the very
  /// edge of the screen). A `null` result from a "Remove photo" tap clears
  /// the value, a plain dismiss leaves it unchanged.
  Future<void> _showMenu() async {
    final l10n = AppLocalizations.of(context)!;
    final choice = await showDialog<_SheetChoice>(
      context: context,
      // Shadow `context` with the dialog's own — using the field's context
      // to pop would pop whatever navigator this field happens to be
      // hosted under (e.g. a bottom-tab's own nested one) instead of just
      // dismissing this dialog.
      builder: (context) => SimpleDialog(
        title: Text(_label(context)),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, const _SheetChoice.camera()),
            child: _MenuRow(
              icon: Icons.photo_camera_outlined,
              label: l10n.actionTakePhoto,
            ),
          ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, const _SheetChoice.gallery()),
            child: _MenuRow(
              icon: Icons.photo_library_outlined,
              label: l10n.actionChooseFromGallery,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, const _SheetChoice.files()),
            child: _MenuRow(
              icon: Icons.folder_open_outlined,
              label: l10n.actionChooseFromFiles,
            ),
          ),
          if (widget.value != null)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, const _SheetChoice.remove()),
              child: _MenuRow(
                icon: Icons.delete_outline,
                label: l10n.actionRemovePhoto,
              ),
            ),
        ],
      ),
    );
    switch (choice?.kind) {
      case _ChoiceKind.camera:
        await _pick(ImageSource.camera);
      case _ChoiceKind.gallery:
        await _pick(ImageSource.gallery);
      case _ChoiceKind.files:
        await _pickFromFiles();
      case _ChoiceKind.remove:
        widget.onChanged(null);
      case null:
        break;
    }
  }
}

enum _ChoiceKind { camera, gallery, files, remove }

class _SheetChoice {
  const _SheetChoice._(this.kind);
  const _SheetChoice.camera() : this._(_ChoiceKind.camera);
  const _SheetChoice.gallery() : this._(_ChoiceKind.gallery);
  const _SheetChoice.files() : this._(_ChoiceKind.files);
  const _SheetChoice.remove() : this._(_ChoiceKind.remove);
  final _ChoiceKind kind;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 16),
        Text(label),
      ],
    );
  }
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
              Text(
                AppLocalizations.of(context)!.actionChange,
                style: Theme.of(context).textTheme.labelMedium,
              ),
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
