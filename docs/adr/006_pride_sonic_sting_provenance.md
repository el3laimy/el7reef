# Pride sonic sting provenance

## Decision

The Android Pride video exporter uses `android/app/src/main/res/raw/pride_sting.wav` as its optional 1.2-second sonic signature.

## Provenance and approval status

- The file is generated entirely from deterministic mathematical synthesis by `tool/generate_pride_sting.js`.
- The generator reads no external audio assets; it synthesizes the motif from the frequencies and equations declared in the script.
- The generated asset is part of the El7reef project and is the candidate sting for exported Pride videos; brand approval is still required.
- Muted exports remain available and the feature stays behind `pride_video_export_enabled` until device QA is complete.

## Reproducibility

- Format: mono PCM WAV, 48 kHz, 16-bit.
- Duration: 1.2 seconds.
- SHA-256: `e21819e04ebbc18f7c426f9e1b7de98fffebbc9e4891f44b23fc851a6f4d755b`.

Regenerate from the repository root:

```bash
node tool/generate_pride_sting.js
```

In the supported Node 20 Linux x64 build environment, regeneration must match the committed hash. Other runtimes must compare their output with that hash before replacing the asset.
