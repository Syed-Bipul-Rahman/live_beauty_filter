## 1.0.0

* Initial release.
* Real-time milky/soft beauty filter on live camera feed, GPU-only via CoreImage + Metal.
* Filter chain: Gaussian blur → Bloom/Glow → Color grade (brightness + contrast lift).
* Adjustable filter intensity at runtime (0.0 → 1.0) via `MilkyFilterController`.
* Drop-in `MilkyCameraView` widget with built-in intensity slider.
* Zero-copy frame delivery to Flutter via `Texture` widget.
* Front camera support with correct mirroring and portrait orientation.
* iOS 14+ only.