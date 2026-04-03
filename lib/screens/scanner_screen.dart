import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  MobileScannerController? _controller;
  bool _hasScanned = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      // Parse the QR content: two lines
      // Line 1: Full Name, Line 2: LRN
      final lines = rawValue.trim().split('\n');

      String name = '';
      String lrn = '';

      if (lines.length >= 2) {
        name = lines[0].trim();
        lrn = lines[1].trim();
      } else if (lines.length == 1) {
        // Try splitting by last space if only one line (fallback)
        final parts = rawValue.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          lrn = parts.last;
          name = parts.sublist(0, parts.length - 1).join(' ');
        } else {
          name = rawValue.trim();
        }
      }

      if (name.isEmpty && lrn.isEmpty) continue;

      setState(() => _hasScanned = true);
      _controller?.stop();

      // Navigate to result screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ResultScreen(name: name, lrn: lrn),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          MobileScanner(
            controller: _controller!,
            onDetect: _handleBarcode,
          ),

          // Overlay
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Scan QR Code',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _torchOn = !_torchOn);
                          _controller?.toggleTorch();
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _torchOn
                                ? Colors.amber.withOpacity(0.8)
                                : Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _torchOn
                                ? Icons.flash_on_rounded
                                : Icons.flash_off_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Scanner viewfinder
                Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      children: [
                        // Dimmed outside area (visual guide only)
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.transparent,
                              width: 0,
                            ),
                          ),
                        ),
                        // Corner decorations
                        ..._buildCorners(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Text(
                    'Align QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const Spacer(),

                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Text(
                    'SPTA Payment Verification',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const double size = 28;
    const double thickness = 4;
    const Color cornerColor = Color(0xFF2563EB);
    const radius = Radius.circular(6);

    return [
      // Top-left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: thickness),
              left: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(topLeft: radius),
          ),
        ),
      ),
      // Top-right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: cornerColor, width: thickness),
              right: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(topRight: radius),
          ),
        ),
      ),
      // Bottom-left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: thickness),
              left: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomLeft: radius),
          ),
        ),
      ),
      // Bottom-right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: cornerColor, width: thickness),
              right: BorderSide(color: cornerColor, width: thickness),
            ),
            borderRadius: BorderRadius.only(bottomRight: radius),
          ),
        ),
      ),
    ];
  }
}
