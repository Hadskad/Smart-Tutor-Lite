#import "whisper_wrapper.h"

#import <Foundation/Foundation.h>

#include <algorithm>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <memory>
#include <sstream>
#include <string>
#include <vector>

// whisper.cpp v1.6.2 flat structure (iOS)
#if __has_include("third_party/whisper.h")
#define SMART_TUTOR_HAS_NATIVE_WHISPER 1
#include "third_party/whisper.h"
#elif __has_include("whisper.h")
#define SMART_TUTOR_HAS_NATIVE_WHISPER 1
#include "whisper.h"
#else
#define SMART_TUTOR_HAS_NATIVE_WHISPER 0
#endif

// Include whisper.cpp implementation for static compilation
#if SMART_TUTOR_HAS_NATIVE_WHISPER
#if __has_include("third_party/whisper.cpp")
#include "third_party/whisper.cpp"
#endif
#endif

namespace {

struct WhisperContext {
#if SMART_TUTOR_HAS_NATIVE_WHISPER
  std::unique_ptr<whisper_context, decltype(&::whisper_free)> ctx;
#else
  std::string modelPath;
#endif
};

char *CopyCString(const std::string &value) {
  char *buffer = static_cast<char *>(malloc(value.size() + 1));
  if (buffer == nullptr) {
    return nullptr;
  }
  ::memcpy(buffer, value.c_str(), value.size());
  buffer[value.size()] = '\0';
  return buffer;
}

std::string BytesToString(const uint8_t *bytes, size_t length) {
  return std::string(reinterpret_cast<const char *>(bytes), length);
}

#if SMART_TUTOR_HAS_NATIVE_WHISPER
int DetermineThreadCount() {
  const NSInteger cores = MAX(1, [[NSProcessInfo processInfo] processorCount]);
  return static_cast<int>(MIN(4, cores));
}

std::string RunWhisperInference(
    WhisperContext *context,
    const std::vector<float> &floatSamples) {
  auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.n_threads = DetermineThreadCount();
  params.print_progress = false;
  params.print_realtime = false;
  params.print_special = false;
  params.translate = false;
  params.single_segment = false;
  params.temperature = 0.0f;
  params.no_context = true;

  const int status = whisper_full(
      context->ctx.get(),
      params,
      floatSamples.data(),
      static_cast<int>(floatSamples.size()));
  if (status != 0) {
    std::ostringstream error;
    error << "whisper_full failed with status " << status;
    throw std::runtime_error(error.str());
  }

  std::ostringstream transcript;
  const int segments = whisper_full_n_segments(context->ctx.get());
  for (int i = 0; i < segments; ++i) {
    const char *segment =
        whisper_full_get_segment_text(context->ctx.get(), i);
    if (segment != nullptr && std::strlen(segment) > 0) {
      if (transcript.tellp() > 0) {
        transcript << ' ';
      }
      transcript << segment;
    }
  }
  return transcript.str();
}
#endif

}  // namespace

extern "C" {

WhisperContext *whisper_init(const char *model_path) {
  @autoreleasepool {
    try {
#if SMART_TUTOR_HAS_NATIVE_WHISPER
      // Use context params with GPU acceleration enabled (Metal on iOS)
      whisper_context_params cparams = whisper_context_default_params();
#ifdef GGML_USE_METAL
      cparams.use_gpu = true;
      NSLog(@"whisper_init: Metal GPU acceleration enabled");
#else
      cparams.use_gpu = false;
      NSLog(@"whisper_init: Using CPU-only mode");
#endif
      auto *ctx = ::whisper_init_from_file_with_params(model_path, cparams);
      if (ctx == nullptr) {
        throw std::runtime_error("Failed to load whisper.cpp model");
      }
      return new WhisperContext{
          std::unique_ptr<whisper_context, decltype(&::whisper_free)>(
              ctx, ::whisper_free)};
#else
      return new WhisperContext{model_path ? std::string(model_path) : ""};
#endif
    } catch (const std::exception &ex) {
      NSLog(@"whisper_init failure: %s", ex.what());
      return nullptr;
    }
  }
}

char *whisper_process(WhisperContext *context,
                      const int16_t *samples,
                      int sample_count) {
  if (context == nullptr || samples == nullptr || sample_count <= 0) {
    return CopyCString("");
  }
  @autoreleasepool {
    try {
      std::vector<float> floatSamples(sample_count);
      constexpr float kScale = 1.0f / 32768.0f;
      for (int i = 0; i < sample_count; ++i) {
        floatSamples[i] = static_cast<float>(samples[i]) * kScale;
      }
#if SMART_TUTOR_HAS_NATIVE_WHISPER
      const std::string transcript =
          RunWhisperInference(context, floatSamples);
      return CopyCString(transcript);
#else
      std::ostringstream stub;
      stub << "[iOS stub] processed " << sample_count << " samples for "
           << context->modelPath;
      return CopyCString(stub.str());
#endif
    } catch (const std::exception &ex) {
      NSLog(@"whisper_process failure: %s", ex.what());
      return CopyCString("");
    }
  }
}

void whisper_free(WhisperContext *context) {
  delete context;
}

}  // extern "C"

