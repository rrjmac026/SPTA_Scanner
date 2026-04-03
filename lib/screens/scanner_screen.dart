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
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue == null || rawValue.isEmpty) continue;

      final lines = rawValue.trim().split('\n');
      String name = '';
      String lrn = '';

      if (lines.length >= 2) {
        name = lines[0].trim();
        lrn = lines[1].trim();
      } else {
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
          MobileScanner(
            controller: _controller!,
            onDetect: _handleBarcode,
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _iconBtn(
                          Icons.arrow_back_rounded, () => Navigator.pop(context)),
                      const Expanded(
                        child: Text('Scan QR Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
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
                SizedBox(
                  width: 260,
                  height: 260,
                  child: Stack(children: _buildCorners()),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Text('Align QR code within the frame',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Text('SPTA Payment Verification',
                      style:
                          TextStyle(color: Colors.white54, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const size = 28.0;
    const thickness = 4.0;
    const color = Color(0xFF2563EB);
    const radius = Radius.circular(6);
    return [
      Positioned(
          top: 0,
          left: 0,
          child: _corner(
              const Border(
                  top: BorderSide(color: color, width: thickness),
                  left: BorderSide(color: color, width: thickness)),
              const BorderRadius.only(topLeft: radius),
              size)),
      Positioned(
          top: 0,
          right: 0,
          child: _corner(
              const Border(
                  top: BorderSide(color: color, width: thickness),
                  right: BorderSide(color: color, width: thickness)),
              const BorderRadius.only(topRight: radius),
              size)),
      Positioned(
          bottom: 0,
          left: 0,
          child: _corner(
              const Border(
                  bottom: BorderSide(color: color, width: thickness),
                  left: BorderSide(color: color, width: thickness)),
              const BorderRadius.only(bottomLeft: radius),
              size)),
      Positioned(
          bottom: 0,
          right: 0,
          child: _corner(
              const Border(
                  bottom: BorderSide(color: color, width: thickness),
                  right: BorderSide(color: color, width: thickness)),
              const BorderRadius.only(bottomRight: radius),
              size)),
    ];
  }

  Widget _corner(Border border, BorderRadius radius, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: border, borderRadius: radius),
    );
  }
}
