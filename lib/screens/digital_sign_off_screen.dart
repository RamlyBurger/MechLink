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
  double _customerRating = 0.0;
  final TextEditingController _feedbackController = TextEditingController();
  Map<String, dynamic>? _jobDetails;
  bool _isLoadingJob = true;

  Future<void> _saveSignature() async {
    // Rating is required
    if (_customerRating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a customer rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? base64Signature;

      if (_hasSignature) {
        // Capture new signature from canvas
        final RenderRepaintBoundary boundary =
            _signatureKey.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (byteData != null) {
          final Uint8List signatureBytes = byteData.buffer.asUint8List();
          base64Signature = base64Encode(signatureBytes);
        }
      } else if (_jobDetails != null &&
          _jobDetails!['digitalSignOff'] != null) {
        // Reuse existing signature if present (user only edits rating/feedback)
        base64Signature = _getBase64String(_jobDetails!['digitalSignOff']);
      }

      if (base64Signature == null || base64Signature.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide your signature'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Save to Firebase with customer rating and feedback
      final success = await _jobDetailService.saveDigitalSignOffWithRating(
        widget.jobId,
        base64Signature,
        _customerRating,
        _feedbackController.text.trim(),
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Digital signature and customer rating saved successfully',
            ),
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

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadJobDetails() async {
    try {
      final jobDetails = await _jobDetailService.getJobWithCompleteDetails(
        widget.jobId,
      );
      if (mounted) {
        setState(() {
          _jobDetails = jobDetails;
          _isLoadingJob = false;
          // Check if job is already completed to prevent modification
          if (_jobDetails?['status'] == 'completed') {
            // Pre-populate existing data if available
            if (_jobDetails?['customerRating'] != null) {
              _customerRating = (_jobDetails!['customerRating'] as num)
                  .toDouble();
            }
            if (_jobDetails?['customerFeedback'] != null) {
              _feedbackController.text = _jobDetails!['customerFeedback'];
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingJob = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading job details: $e')),
        );
      }
    }
  }

  void _refreshCanvas() {
    setState(() {
      _canvasVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingJob) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Digital Sign Off - ${widget.jobTitle}'),
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isJobCompleted = _jobDetails?['status'] == 'completed';
    final bool hasExistingSignOff = _jobDetails?['digitalSignOff'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Digital Sign Off - ${widget.jobTitle}'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          if (!isJobCompleted) ...[
            IconButton(
              onPressed: _isSaving ? null : _refreshCanvas,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Canvas',
            ),
            TextButton(
              onPressed: _isSaving ? null : _clearSignature,
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Instructions
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isJobCompleted ? Colors.green.shade50 : Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isJobCompleted ? Icons.verified : Icons.info_outline,
                      color: isJobCompleted
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isJobCompleted
                          ? 'Job Completed - View Only'
                          : 'Digital Signature Required',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isJobCompleted
                            ? Colors.green.shade800
                            : Colors.blue.shade800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isJobCompleted
                      ? 'This job has been completed. The signature and rating cannot be modified.'
                      : 'Please sign below and provide a customer rating to confirm job completion. Your signature will be stored securely and used for job verification.',
                  style: TextStyle(
                    color: isJobCompleted
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Customer Rating Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star_rate,
                      color: Colors.amber.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Customer Rating',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(5, (index) {
                    return GestureDetector(
                      onTap: isJobCompleted
                          ? null
                          : () {
                              setState(() {
                                _customerRating = (index + 1).toDouble();
                              });
                            },
                      child: Icon(
                        index < _customerRating
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber.shade600,
                        size: 32,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _feedbackController,
                  enabled: !isJobCompleted,
                  decoration: const InputDecoration(
                    labelText: 'Customer Feedback (Optional)',
                    hintText:
                        'Enter any additional feedback from the customer...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
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
                    child: hasExistingSignOff && isJobCompleted
                        ? _buildExistingSignature()
                        : GestureDetector(
                            onPanStart: isJobCompleted
                                ? null
                                : (details) {
                                    setState(() {
                                      _points.add(details.localPosition);
                                      _hasSignature = true;
                                      _canvasVersion++;
                                    });
                                  },
                            onPanUpdate: isJobCompleted
                                ? null
                                : (details) {
                                    setState(() {
                                      _points.add(details.localPosition);
                                      _canvasVersion++;
                                    });
                                  },
                            onPanEnd: isJobCompleted
                                ? null
                                : (details) {
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
                                child:
                                    Container(), // This ensures the CustomPaint takes full size
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
                Container(height: 1, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'Signature',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
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
                    child: Text(isJobCompleted ? 'Close' : 'Cancel'),
                  ),
                ),
                if (!isJobCompleted) ...[
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingSignature() {
    if (_jobDetails?['digitalSignOff'] == null) {
      return const Center(
        child: Text(
          'No signature available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    try {
      final String signatureData = _jobDetails!['digitalSignOff'];
      final String base64String = _getBase64String(signatureData);

      return Image.memory(
        base64Decode(base64String),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Text(
              'Failed to load signature',
              style: TextStyle(color: Colors.red),
            ),
          );
        },
      );
    } catch (e) {
      return const Center(
        child: Text(
          'Error loading signature',
          style: TextStyle(color: Colors.red),
        ),
      );
    }
  }

  /// Extract base64 string from data URL or return as-is if already base64
  String _getBase64String(String input) {
    if (input.startsWith('data:')) {
      // Remove data URL prefix (e.g., "data:image/png;base64,")
      final commaIndex = input.indexOf(',');
      if (commaIndex != -1) {
        return input.substring(commaIndex + 1);
      }
    }
    return input;
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
