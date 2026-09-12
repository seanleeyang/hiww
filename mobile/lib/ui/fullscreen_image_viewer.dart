import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/image_saver/image_saver.dart';
import '../l10n/app_localizations.dart';

/// Opens [url] full-screen, pinch-to-zoomable, with a "Save to device" action
/// so a traveler can grab a copy before losing signal at the shop.
Future<void> showFullscreenImage(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black,
    builder: (_) => _FullscreenImageViewer(url: url),
  );
}

class _FullscreenImageViewer extends StatefulWidget {
  const _FullscreenImageViewer({required this.url});
  final String url;

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  bool _saving = false;

  Future<void> _download() async {
    setState(() => _saving = true);
    try {
      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final result = await saveImageBytes(Uint8List.fromList(response.data!));
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      _toast(switch (result) {
        SaveResult.success => l10n.infoSavedToDevice,
        SaveResult.permissionDenied => l10n.errorPhotoAccessDenied,
        SaveResult.failure => l10n.errorSaveImageFailed,
      });
    } catch (_) {
      if (mounted) _toast(AppLocalizations.of(context)!.errorSaveImageFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: CachedNetworkImage(
                imageUrl: widget.url,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: Center(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _download,
                  icon: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_outlined),
                  label: Text(
                    _saving
                        ? AppLocalizations.of(context)!.actionSaving
                        : AppLocalizations.of(context)!.actionSaveToDevice,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
