import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../models/models.dart';
import '../../state/core_providers.dart';
import '../../widgets/toast.dart';

/// The picker is a provider so tests can supply their own images.
final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

String _contentTypeFor(XFile file) {
  final mime = file.mimeType;
  if (mime != null && mime.startsWith('image/')) {
    return mime;
  }
  final name = file.name.toLowerCase();
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.gif')) return 'image/gif';
  if (name.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// A multipart part without a file name is not treated as a file by the server, so never send one.
String _filenameFor(XFile file, String contentType) {
  if (file.name.isNotEmpty) {
    return file.name;
  }
  final extension = switch (contentType) {
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
  return 'image.$extension';
}

/// Picks an image from the gallery or camera, uploads it and reports the stored media.
class MediaUploader extends ConsumerStatefulWidget {
  const MediaUploader({super.key, this.value, this.onChanged});

  final MediaInfo? value;
  final ValueChanged<MediaInfo?>? onChanged;

  @override
  ConsumerState<MediaUploader> createState() => _MediaUploaderState();
}

class _MediaUploaderState extends ConsumerState<MediaUploader> {
  bool _uploading = false;

  Future<ImageSource?> _chooseSource() {
    // Desktop and web have no camera to offer.
    final hasCamera = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    if (!hasCamera) {
      return Future.value(ImageSource.gallery);
    }
    return showModalBottomSheet<ImageSource>(
      context: context,
      useRootNavigator: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(String successMessage) async {
    final source = await _chooseSource();
    if (source == null) {
      return;
    }
    setState(() => _uploading = true);
    try {
      final file = await ref.read(imagePickerProvider).pickImage(source: source);
      if (file == null) {
        return;
      }
      final contentType = _contentTypeFor(file);
      final media = await ref.read(mediaApiProvider).uploadMedia(
            bytes: await file.readAsBytes(),
            filename: _filenameFor(file, contentType),
            contentType: contentType,
          );
      widget.onChanged?.call(media);
      Toast.success(successMessage);
    } catch (_) {
      Toast.error('Upload failed');
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.value?.url;
    if (url == null || url.isEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _uploading ? null : () => _pickAndUpload('Image uploaded'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.dashedBorder),
          ),
          child: Column(
            children: [
              if (_uploading)
                const SizedBox(width: 40, height: 40, child: CircularProgressIndicator())
              else
                const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.primary),
              const SizedBox(height: 8),
              const Text('Add an image', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(_uploading ? 'Uploading…' : 'Tap to choose a photo', style: AppText.secondary),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: _uploading ? 0.45 : 1, child: PostImage(url: url, label: 'Preview')),
            if (_uploading)
              const Column(
                mainAxisSize: MainAxisSize.min,
                children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Uploading…')],
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _uploading ? null : () => _pickAndUpload('Image replaced'),
                child: const Text('Replace image'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger),
              ),
              onPressed: _uploading ? null : () => widget.onChanged?.call(null),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A post image shown whole (contained) on a light background with a rounded border.
class PostImage extends StatelessWidget {
  const PostImage({super.key, required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        semanticLabel: label,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        errorBuilder: (context, error, stack) => const SizedBox(
          height: 200,
          child: Center(child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.disabledText)),
        ),
      ),
    );
  }
}
