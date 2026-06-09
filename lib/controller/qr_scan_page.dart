import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../network/room_connection_uri.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_hasResult) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      final uri = value == null ? null : RoomConnectionUri.normalize(value);
      if (uri != null) {
        _hasResult = true;
        Navigator.of(context).pop(uri.toString());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan room QR')),
      body: SafeArea(
        child: Stack(
          children: [
            MobileScanner(controller: _controller, onDetect: _handleDetect),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Colors.black.withValues(alpha: 0.72),
                child: Text(
                  'Scan the QR code shown on the desktop room screen.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
