#include <android/log.h>
#include <jni.h>

#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iterator>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include "whisper_wrapper.h"

#ifndef __has_include
#define __has_include(x) 0
#endif

#if __has_include("whisper.h")
#define SMART_TUTOR_HAS_NATIVE_WHISPER 1
#include "whisper.h"
#else
#define SMART_TUTOR_HAS_NATIVE_WHISPER 0
#endif

#define LOG_TAG "WhisperJNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

struct WhisperContextImpl {
#if SMART_TUTOR_HAS_NATIVE_WHISPER
  std::unique_ptr<whisper_context, decltype(&::whisper_free)> ctx;
#else
  std::string modelPath;
#endif
};

char *CopyCString(const std::string &value) {
  auto *buffer = static_cast<char *>(std::malloc(value.size() + 1));
  if (buffer == nullptr) {
    throw std::bad_alloc();
  }
  std::memcpy(buffer, value.c_str(), value.size() + 1);
  return buffer;
}

std::vector<uint8_t> ReadBinaryFile(const std::string &path) {
  std::ifstream file(path, std::ios::binary);
  if (!file.is_open()) {
    std::ostringstream error;
    error << "Unable to open audio file: " << path << " (" << std::strerror(errno)
          << ")";
    throw std::runtime_error(error.str());
  }
  std::vector<uint8_t> bytes((std::istreambuf_iterator<char>(file)),
                             std::istreambuf_iterator<char>());
  return bytes;
}

std::vector<int16_t> ParseWavSamples(const std::vector<uint8_t> &bytes) {
  if (bytes.size() < 44) {
    throw std::runtime_error("WAV file is too small");
  }
  if (std::strncmp(reinterpret_cast<const char *>(bytes.data()), "RIFF", 4) != 0) {
    throw std::runtime_error("Only PCM WAV files are supported");
  }
  const uint32_t sampleRate =
      *reinterpret_cast<const uint32_t *>(bytes.data() + 24);
  if (sampleRate != 16000) {
    std::ostringstream msg;
    msg << "Expected 16kHz WAV file but found " << sampleRate << "Hz";
    throw std::runtime_error(msg.str());
  }
  const size_t dataOffset = 44;
  const size_t sampleBytes = bytes.size() - dataOffset;
  const size_t sampleCount = sampleBytes / sizeof(int16_t);
  std::vector<int16_t> samples(sampleCount);
  std::memcpy(
      samples.data(),
      bytes.data() + dataOffset,
      sampleCount * sizeof(int16_t));
  return samples;
}

std::string JStringToStdString(JNIEnv *env, jstring value) {
  if (value == nullptr) {
    return {};
  }
  const char *chars = env->GetStringUTFChars(value, nullptr);
  std::string result(chars ? chars : "");
  env->ReleaseStringUTFChars(value, chars);
  return result;
}

#if SMART_TUTOR_HAS_NATIVE_WHISPER
int DetermineThreadCount() {
  const unsigned int hardwareThreads = std::thread::hardware_concurrency();
  if (hardwareThreads == 0) {
    return 2;
  }
  const int safeThreads =
      std::max(1, static_cast<int>(hardwareThreads));
  return std::min(4, safeThreads);
}

std::string RunWhisperInference(
  WhisperContextImpl *context,
    const int16_t *samples,
    int sample_count) {
  std::vector<float> floatSamples(sample_count);
  constexpr float kScale = 1.0f / 32768.0f;
  for (int i = 0; i < sample_count; ++i) {
    floatSamples[i] = static_cast<float>(samples[i]) * kScale;
  }

  auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  params.n_threads = DetermineThreadCount();
  params.print_progress = false;
  params.print_special = false;
  params.print_realtime = false;
  params.translate = false;
  params.single_segment = false;
  params.temperature = 0.0f;
  params.max_tokens = 0;
  params.no_context = true;
  params.offset_ms = 0;

  const int status = whisper_full(
      context->ctx.get(),
      params,
      floatSamples.data(),
      sample_count);
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

WhisperContext *whisper_wrapper_init(const char *model_path) {
  try {
#if SMART_TUTOR_HAS_NATIVE_WHISPER
    whisper_context_params cparams = whisper_context_default_params();
    auto *ctx = ::whisper_init_from_file_with_params(model_path, cparams);
    if (ctx == nullptr) {
      throw std::runtime_error("Unable to initialize whisper.cpp model");
    }
    auto *impl = new WhisperContextImpl{
        std::unique_ptr<whisper_context, decltype(&::whisper_free)>(
            ctx, ::whisper_free)};
    return reinterpret_cast<WhisperContext *>(impl);
#else
    auto *impl = new WhisperContextImpl{std::string(model_path ? model_path : "")};
    return reinterpret_cast<WhisperContext *>(impl);
#endif
  } catch (const std::exception &ex) {
    LOGE("whisper_wrapper_init failed: %s", ex.what());
    return nullptr;
  }
}

char *whisper_wrapper_process(
    WhisperContext *context,
    const int16_t *samples,
    int sample_count) {
  auto *impl = reinterpret_cast<WhisperContextImpl *>(context);
  if (impl == nullptr || samples == nullptr || sample_count <= 0) {
    return CopyCString("");
  }
#if SMART_TUTOR_HAS_NATIVE_WHISPER
  try {
    const std::string transcript =
        RunWhisperInference(impl, samples, sample_count);
    return CopyCString(transcript);
  } catch (const std::exception &ex) {
    LOGE("whisper_wrapper_process failed: %s", ex.what());
    return CopyCString("");
  }
#else
  std::ostringstream message;
  message << "[stub] processed " << sample_count
          << " samples for model: " << impl->modelPath;
  return CopyCString(message.str());
#endif
}

void whisper_wrapper_free(WhisperContext *context) {
  auto *impl = reinterpret_cast<WhisperContextImpl *>(context);
  delete impl;
}

JNIEXPORT jlong JNICALL
Java_com_smarttutor_WhisperPlugin_nativeInitModel(
    JNIEnv *env,
    jobject /*thiz*/,
    jstring model_path) {
  const std::string path = JStringToStdString(env, model_path);
  auto *context = whisper_wrapper_init(path.c_str());
  return reinterpret_cast<jlong>(context);
}

JNIEXPORT jstring JNICALL
Java_com_smarttutor_WhisperPlugin_nativeTranscribe(
    JNIEnv *env,
    jobject /*thiz*/,
    jlong context_ptr,
    jstring audio_path) {
  auto *context = reinterpret_cast<WhisperContext *>(context_ptr);
  if (context == nullptr) {
    LOGE("nativeTranscribe invoked without initializing model");
    return env->NewStringUTF("");
  }

  const std::string path = JStringToStdString(env, audio_path);
  try {
    const auto bytes = ReadBinaryFile(path);
    const auto samples = ParseWavSamples(bytes);
    std::unique_ptr<char, decltype(&std::free)> transcript(
        whisper_wrapper_process(context, samples.data(),
                        static_cast<int>(samples.size())),
        &std::free);
    if (!transcript) {
      return env->NewStringUTF("");
    }
    return env->NewStringUTF(transcript.get());
  } catch (const std::exception &ex) {
    LOGE("nativeTranscribe failed: %s", ex.what());
    return env->NewStringUTF("");
  }
}

JNIEXPORT void JNICALL
Java_com_smarttutor_WhisperPlugin_nativeFree(
    JNIEnv * /*env*/,
    jobject /*thiz*/,
    jlong context_ptr) {
  auto *context = reinterpret_cast<WhisperContext *>(context_ptr);
  whisper_wrapper_free(context);
}

}  // extern "C"

