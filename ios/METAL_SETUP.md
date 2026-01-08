# iOS Metal GPU Acceleration Setup Guide

This guide documents the steps required to enable Metal GPU acceleration for whisper.cpp on iOS.

## Prerequisites
- Xcode 14.0 or later
- iOS deployment target 12.0 or later
- Physical iOS device (Metal not available on simulator)

## Required Files
The following Metal files are already present in `ios/Runner/third_party/`:
- `ggml-metal.h` - Metal backend header
- `ggml-metal.m` - Metal backend implementation
- `ggml-metal.metal` - Metal shader file

## Manual Xcode Configuration Steps

### Step 1: Add Metal Source File to Compile Sources
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** project in the navigator
3. Select the **Runner** target
4. Go to **Build Phases** tab
5. Expand **Compile Sources**
6. Click **+** and add `Runner/third_party/ggml-metal.m`
7. Select the newly added file and set **Compiler Flags** to:
   ```
   -fno-objc-arc -DGGML_USE_METAL=1
   ```

### Step 2: Add Metal Shader to Bundle Resources
1. In **Build Phases**, expand **Copy Bundle Resources**
2. Click **+** and add `Runner/third_party/ggml-metal.metal`

### Step 3: Link Metal Frameworks
1. Go to **Build Phases** tab
2. Expand **Link Binary With Libraries**
3. Click **+** and add:
   - `Metal.framework`
   - `MetalKit.framework`

### Step 4: Add Preprocessor Definition
1. Go to **Build Settings** tab
2. Search for "Preprocessor Macros" or `GCC_PREPROCESSOR_DEFINITIONS`
3. Add `GGML_USE_METAL=1` to both Debug and Release configurations

### Step 5: Update Header Search Paths (if needed)
1. In **Build Settings**, search for "Header Search Paths"
2. Ensure `$(SRCROOT)/Runner/third_party` is included

## Verification
After configuration, build the app and check the Xcode console logs for:
```
whisper_init: Metal GPU acceleration enabled
```

If you see:
```
whisper_init: Using CPU-only mode
```
Then Metal is not properly configured - review the steps above.

## Troubleshooting

### "ggml-metal.metal: Metal library not found"
- Ensure `ggml-metal.metal` is in Copy Bundle Resources
- Verify the file path is correct

### "Undefined symbols for architecture arm64"
- Ensure Metal.framework and MetalKit.framework are linked
- Verify ggml-metal.m is in Compile Sources with correct flags

### Build errors in ggml-metal.m
- Ensure `-fno-objc-arc` flag is set (Metal code requires manual memory management)
- Ensure `-DGGML_USE_METAL=1` is set

## Performance Notes
- Metal acceleration provides 3-5x speedup on supported devices
- Requires iPhone 6s or newer (A9 chip or later)
- First run may be slower due to Metal shader compilation
- Subsequent runs benefit from Metal pipeline caching
