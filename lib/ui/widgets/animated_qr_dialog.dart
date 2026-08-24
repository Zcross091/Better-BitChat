import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/crypto/fountain_qr.dart';
import '../theme/app_theme.dart';

class AnimatedQrBroadcastDialog extends StatefulWidget {
  final String payload;
  final String title;

  const AnimatedQrBroadcastDialog({
    super.key,
    required this.payload,
    this.title = 'Fountain QR Sneakernet Stream',
  });

  @override
  State<AnimatedQrBroadcastDialog> createState() => _AnimatedQrBroadcastDialogState();
}

class _AnimatedQrBroadcastDialogState extends State<AnimatedQrBroadcastDialog> {
  late final List<FountainDroplet> _droplets;
  int _currentFrame = 0;
  Timer? _animationTimer;
  bool _isPlaying = true;
  int _fps = 6; // 6 frames per second

  @override
  void initState() {
    super.initState();
    final engine = FountainQrEngine(maxChunkChars: 220);
    _droplets = engine.encodePayload(widget.payload);
    _startAnimation();
  }

  void _startAnimation() {
    _animationTimer?.cancel();
    if (_droplets.length <= 1) return;

    _animationTimer = Timer.periodic(Duration(milliseconds: (1000 / _fps).round()), (timer) {
      if (!mounted) return;
      setState(() {
        _currentFrame = (_currentFrame + 1) % _droplets.length;
      });
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentDroplet = _droplets.isEmpty
        ? FountainDroplet(seq: 0, total: 1, checksum: '', chunk: '')
        : _droplets[_currentFrame];
    final serializedData = currentDroplet.serialize();

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Row(
        children: [
          const Icon(LucideIcons.radio, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Air-Gapped Optical Transfer (Frame ${_currentFrame + 1} of ${_droplets.length})',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),

          // High-contrast QR Container
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: serializedData,
              version: QrVersions.auto,
              size: 220.0,
              gapless: true,
            ),
          ),
          const SizedBox(height: 12),

          // Progress Bar
          LinearProgressIndicator(
            value: _droplets.isEmpty ? 1.0 : (_currentFrame + 1) / _droplets.length,
            backgroundColor: AppTheme.surfaceElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
          const SizedBox(height: 12),

          // Speed & Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(_isPlaying ? LucideIcons.pause : LucideIcons.play, size: 18),
                    onPressed: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                        if (_isPlaying) {
                          _startAnimation();
                        } else {
                          _animationTimer?.cancel();
                        }
                      });
                    },
                  ),
                  Text('${_fps} fps', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(LucideIcons.minus, size: 16),
                    onPressed: () {
                      if (_fps > 2) {
                        setState(() {
                          _fps -= 2;
                          _startAnimation();
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.plus, size: 16),
                    onPressed: () {
                      if (_fps < 14) {
                        setState(() {
                          _fps += 2;
                          _startAnimation();
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
