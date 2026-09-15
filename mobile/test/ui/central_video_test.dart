import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiww_mobile/ui/central_video.dart';

void main() {
  testWidgets('fills whatever box its caller gives it before the video initializes', (tester) async {
    // video_player has no platform implementation in the plain widget-test
    // VM, so initialize() never completes here — this only checks that
    // CentralVideo defers entirely to its parent's constraints (no fixed
    // size of its own) rather than that a real frame renders.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 240,
          height: 180,
          child: CentralVideo(asset: 'assets/video/piggy_bank.mp4'),
        ),
      ),
    ));
    await tester.pump();

    final size = tester.getSize(find.byType(CentralVideo));
    expect(size, const Size(240, 180));
  });
}
