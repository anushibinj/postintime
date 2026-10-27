import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:postintime/features/posts/media_uploader.dart';

import '../support/harness.dart';

/// Hands the uploader an image without touching the platform's gallery.
class FakeImagePicker extends ImagePicker {
  FakeImagePicker({this.file, this.fail = false});

  XFile? file;
  final bool fail;
  final List<ImageSource> requested = [];

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    requested.add(source);
    if (fail) {
      throw Exception('gallery unavailable');
    }
    return file;
  }
}

/// A picked photo. Like on a phone, it lives at a path, which is where its name comes from.
XFile photo(String name, {String? mimeType}) =>
    XFile.fromData(Uint8List.fromList([1, 2, 3, 4]), name: name, path: '/cache/$name', mimeType: mimeType);

/// Opens the new post form of a fresh channel with [picker] standing in for the gallery.
Future<TestApp> openNewPost(WidgetTester tester, FakeImagePicker picker) async {
  final app = await createApp();
  app.backend.addChannel(name: 'Tech', slug: 'tech');
  usePhoneScreen(tester);
  await pumpApp(tester, app, extra: [imagePickerProvider.overrideWithValue(picker)]);
  await tapText(tester, 'View');
  await tapText(tester, 'New Post');
  return app;
}

void main() {
  testWidgets('uploads a chosen photo, previews it and attaches it to the new post', (tester) async {
    final picker = FakeImagePicker(file: photo('cat.png', mimeType: 'image/png'));
    final app = await openNewPost(tester, picker);

    expect(find.text('Add an image'), findsOneWidget);
    await tapText(tester, 'Add an image');
    // On phones the user picks the source first.
    await tapText(tester, 'Choose from gallery');

    expect(picker.requested, [ImageSource.gallery]);
    expect(find.text('Image uploaded'), findsOneWidget);
    expect(find.text('Replace image'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    expect(find.text('Add an image'), findsNothing);
    final upload = app.backend.bodies[app.backend.log.indexOf('POST /api/v1/media')]! as Map;
    expect(upload['_files'], ['file:cat.png:image/png']);

    await tester.enterText(find.widgetWithText(TextField, '').first, 'Cat day');
    await tester.pump();
    await tapText(tester, 'Create post');

    final create = app.backend.bodies[app.backend.log.indexWhere((e) => e.startsWith('POST') && e.endsWith('/posts'))]! as Map;
    expect(create['mediaId'], startsWith('media-'));
    expect(find.text('View post'), findsOneWidget);
    expect(find.text('No image'), findsNothing);
  });

  testWidgets('can take a photo with the camera', (tester) async {
    final picker = FakeImagePicker(file: photo('shot.jpg'));
    await openNewPost(tester, picker);
    await tapText(tester, 'Add an image');
    await tapText(tester, 'Take a photo');
    expect(picker.requested, [ImageSource.camera]);
    expect(find.text('Image uploaded'), findsOneWidget);
  });

  testWidgets('works out the content type from the file name when the picker gives none', (tester) async {
    final picker = FakeImagePicker(file: photo('banner.webp'));
    final app = await openNewPost(tester, picker);
    await tapText(tester, 'Add an image');
    await tapText(tester, 'Choose from gallery');
    final upload = app.backend.bodies[app.backend.log.indexOf('POST /api/v1/media')]! as Map;
    expect(upload['_files'], ['file:banner.webp:image/webp']);
  });

  testWidgets('gives a nameless pick a file name so the server sees a file', (tester) async {
    final picker = FakeImagePicker(file: XFile.fromData(Uint8List.fromList([1, 2, 3]), mimeType: 'image/png'));
    final app = await openNewPost(tester, picker);
    await tapText(tester, 'Add an image');
    await tapText(tester, 'Choose from gallery');
    final upload = app.backend.bodies[app.backend.log.indexOf('POST /api/v1/media')]! as Map;
    expect(upload['_files'], ['file:image.png:image/png']);
  });

  testWidgets('replaces and removes the image', (tester) async {
    final picker = FakeImagePicker(file: photo('one.png', mimeType: 'image/png'));
    final app = await openNewPost(tester, picker);
    await tapText(tester, 'Add an image');
    await tapText(tester, 'Choose from gallery');

    picker.file = photo('two.png', mimeType: 'image/png');
    await tapText(tester, 'Replace image');
    await tapText(tester, 'Choose from gallery');
    expect(find.text('Image replaced'), findsOneWidget);
    expect(app.backend.log.where((e) => e == 'POST /api/v1/media'), hasLength(2));

    await tapText(tester, 'Remove');
    expect(find.text('Add an image'), findsOneWidget);
    expect(find.text('Replace image'), findsNothing);
  });

  testWidgets('cancelling the picker uploads nothing', (tester) async {
    final picker = FakeImagePicker();
    final app = await openNewPost(tester, picker);
    await tapText(tester, 'Add an image');
    await tapText(tester, 'Choose from gallery');
    expect(app.backend.log.where((e) => e == 'POST /api/v1/media'), isEmpty);
    expect(find.text('Add an image'), findsOneWidget);
    expect(find.text('Upload failed'), findsNothing);
  });

  testWidgets('shows an error when the upload fails', (tester) async {
    final picker = FakeImagePicker(fail: true);
    await openNewPost(tester, picker);
    await tapText(tester, 'Add an image');
    await tapText(tester, 'Choose from gallery');
    expect(find.text('Upload failed'), findsOneWidget);
    expect(find.text('Add an image'), findsOneWidget);
  });

  testWidgets('editing a post shows its current image and keeps it', (tester) async {
    final app = await createApp();
    final channelId = app.backend.addChannel(name: 'Tech', slug: 'tech')['id']! as String;
    app.backend.addPost(channelId, title: 'With image', media: {
      'id': 'media-x',
      'url': 'http://fake.test/api/v1/media/files/x.png',
      'contentType': 'image/png',
    });
    await pumpApp(tester, app, extra: [imagePickerProvider.overrideWithValue(FakeImagePicker())]);
    await tapText(tester, 'View');
    await tapText(tester, 'With image');
    expect(find.text('No image'), findsNothing);
    await tester.tap(find.byTooltip('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Replace image'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
    await tapText(tester, 'Save changes');
    final patch = app.backend.bodies[app.backend.log.lastIndexWhere((e) => e.startsWith('PATCH'))]! as Map;
    expect(patch['mediaId'], 'media-x');
  });
}
