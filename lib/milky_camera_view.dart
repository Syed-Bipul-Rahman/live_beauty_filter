import 'package:flutter/material.dart';
import 'milky_filter_controller.dart';

class MilkyCameraView extends StatefulWidget {
  const MilkyCameraView({super.key});

  @override
  State<MilkyCameraView> createState() => _MilkyCameraViewState();
}

class _MilkyCameraViewState extends State<MilkyCameraView> {
  final _controller = MilkyFilterController();
  double _intensity = 0.7;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Zero-copy GPU texture — no pixel data crosses to Dart
        Texture(textureId: _controller.textureId!),

        // Intensity slider
        Positioned(
          bottom: 40,
          left: 24,
          right: 24,
          child: Column(
            children: [
              const Text(
                'Milky intensity',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              Slider(
                value: _intensity,
                min: 0,
                max: 1,
                onChanged: (v) {
                  setState(() => _intensity = v);
                  _controller.setFilterIntensity(v);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
