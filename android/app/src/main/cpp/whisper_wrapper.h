#pragma once

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WhisperContext WhisperContext;

WhisperContext *whisper_init(const char *model_path);
char *whisper_process(
    WhisperContext *context,
    const int16_t *samples,
    int sample_count);
void whisper_free(WhisperContext *context);

#ifdef __cplusplus
}
#endif

