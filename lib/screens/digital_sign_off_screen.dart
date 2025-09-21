import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mechlink/services/job_detail_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

class DigitalSignOffScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const DigitalSignOffScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<DigitalSignOffScreen> createState() => _DigitalSignOffScreenState();
}

class _DigitalSignOffScreenState extends State<DigitalSignOffScreen> {
  final List<Offset> _points = [];
  final GlobalKey _signatureKey = GlobalKey();
  final JobDetailService _jobDetailService = JobDetailService();
  int _canvasVersion = 0;
  bool _isSaving = false;
  bool _hasSignature = false;

  Future<void> _saveSignature() async {
    if (!_hasSignature) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide your signature'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Capture signature as image
      final RenderRepaintBoundary boundary = _signatureKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List signatureBytes = byteData.buffer.asUint8List();

        // Convert to base64
        final String base64Signature = base64Encode(signatureBytes);

        // Save to Firebase
        final success = await _jobDetailService.saveDigitalSignOff(
          widget.jobId,
          base64Signature,
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Digital signature saved successfully'),
              backgroundColor: Colors.green,
            ),
          );

          // Return to job detail screen
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save signature'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving signature: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
      _hasSignature = false;
      _canvasVersion++;
    });
  }

  void _refreshCanvas() {
    setState(() {
      _canvasVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Digital Sign Off - ${widget.jobTitle}'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _refreshCanvas,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Canvas',
          ),
          TextButton(
            onPressed: _isSaving ? null : _clearSignature,
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Digital Signature Required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Please sign below to confirm job completion. Your signature will be stored securely and used for job verification.',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Signature pad
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RepaintBoundary(
                  key: _signatureKey,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.white,
                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _points.add(details.localPosition);
                          _hasSignature = true;
                          _canvasVersion++;
                        });
                      },
                      onPanUpdate: (details) {
                        setState(() {
                          _points.add(details.localPosition);
                          _canvasVersion++;
                        });
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _points.add(Offset.infinite);
                          _canvasVersion++;
                        });
                      },
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: CustomPaint(
                          key: ValueKey(_canvasVersion),
                          painter: SignaturePainter(_points),
                          child: Container(), // This ensures the CustomPaint takes full size
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Signature line
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Container(
                  height: 1,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 8),
                Text(
                  'Signature',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Text('Finish'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    if (points.isEmpty) return;

    Path path = Path();
    bool pathStarted = false;

    for (int i = 0; i < points.length; i++) {
      if (points[i] == Offset.infinite) {
        // End of stroke, start a new path for the next stroke
        pathStarted = false;
      } else {
        if (!pathStarted) {
          // Start a new stroke
          path.moveTo(points[i].dx, points[i].dy);
          pathStarted = true;
        } else {
          // Continue the current stroke
          path.lineTo(points[i].dx, points[i].dy);
        }
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return true; // Always repaint to ensure drawing shows up
  }
}
