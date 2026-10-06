# SharedPackages

These packages contain reusable capabilities intended for multiple products.
They must not depend on application or Cockpit targets.

| Package | Responsibility |
| --- | --- |
| `ILSFoundation` | Logging, math, and framework-independent value types |
| `ILSEngine` | Reusable RealityKit components and systems |
| `ILSNetwork` | Generic HTTP transport, request building, and interceptors |
| `ILSDesignSystem` | Fonts, UI tokens, and SwiftUI adapters |
| `ILSSharePlay` | Generic GroupActivities lifecycle and typed messaging |
| `ILSHandTracking` | Reusable hand tracking and pose production |
| `ILSSpatialAudio` | Spatial audio playback with injectable resource loading |
| `ILSSpatialDraw` | Spatial drawing and its optional collaboration behavior |
| `ILSRealityAssets` | Explicitly selected shared RealityKit resources |

Product-specific roles, messages, API paths, scoring rules, progress models,
asset policies, and authored entity names belong to the consuming product.
