#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANDROID_THIRD_PARTY="$ROOT_DIR/android/app/src/main/cpp/third_party"
IOS_THIRD_PARTY="$ROOT_DIR/ios/Runner/third_party"
MODELS_DIR="$ROOT_DIR/assets/models"
VERSION_FILE=".whisper-version"
WHISPER_VERSION="${WHISPER_VERSION:-v1.6.2}"
WHISPER_ARCHIVE_URL="https://github.com/ggerganov/whisper.cpp/archive/refs/tags/${WHISPER_VERSION}.tar.gz"
MODEL_BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"
DEFAULT_MODELS=("ggml-base.en.bin" "ggml-tiny.en.bin")

ensure_tool() {
  if command -v "$1" >/dev/null 2>&1; then
    return 0;
  fi
  return 1
}

fetch_file() {
  local url="$1"
  local dest="$2"
  if ensure_tool curl; then
    curl -L "$url" -o "$dest"
  elif ensure_tool wget; then
    wget -O "$dest" "$url"
  else
    echo "💥 Please install curl or wget to continue." >&2
    exit 1
  fi
}

copy_sources() {
  local src="$1"
  local dest="$2"
  mkdir -p "$dest"
  if ensure_tool rsync; then
    rsync -a --delete --exclude '.git' --exclude '.github' "$src/" "$dest/"
  else
    find "$dest" -mindepth 1 -maxdepth 1 ! -name '.gitkeep' -exec rm -rf {} +
    cp -R "$src/." "$dest/"
    rm -rf "$dest/.git" "$dest/.github" || true
  fi
  printf "%s" "$WHISPER_VERSION" > "$dest/$VERSION_FILE"
}

install_whisper_sources() {
  local target_dir="$1"
  local version_file="$target_dir/$VERSION_FILE"
  if [[ -f "$version_file" ]] && [[ "$(cat "$version_file")" == "$WHISPER_VERSION" ]]; then
    echo "✅ whisper.cpp $WHISPER_VERSION already installed in ${target_dir#$ROOT_DIR/}"
    return
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' RETURN

  echo "⬇️  Downloading whisper.cpp $WHISPER_VERSION..."
  local archive="$tmp_dir/whisper.tar.gz"
  fetch_file "$WHISPER_ARCHIVE_URL" "$archive"
  tar -xzf "$archive" -C "$tmp_dir"
  local extracted
  extracted="$(find "$tmp_dir" -maxdepth 1 -type d -name "whisper.cpp-*")"
  if [[ -z "$extracted" ]]; then
    echo "Could not find extracted whisper.cpp sources." >&2
    exit 1
  fi
  echo "📦 Installing sources into ${target_dir#$ROOT_DIR/}"
  copy_sources "$extracted" "$target_dir"
  echo "✅ whisper.cpp $WHISPER_VERSION installed in ${target_dir#$ROOT_DIR/}"
}

install_models() {
  mkdir -p "$MODELS_DIR"
  local models=("${WHISPER_MODELS[@]:-${DEFAULT_MODELS[@]}}")
  for model in "${models[@]}"; do
    local dest="$MODELS_DIR/$model"
    if [[ -f "$dest" ]]; then
      echo "✅ Model ${model} already present."
      continue
    fi
    echo "⬇️  Downloading model ${model}..."
    fetch_file "${MODEL_BASE_URL}/${model}" "$dest"
    echo "✅ Saved to ${dest#$ROOT_DIR/}"
  done
}

main() {
  echo "🔧 Setting up native Whisper dependencies..."
  install_whisper_sources "$ANDROID_THIRD_PARTY"
  install_whisper_sources "$IOS_THIRD_PARTY"
  install_models
  echo ""
  echo "All done! The native libraries will switch to full whisper.cpp inference"
  echo "the next time you build the Android or iOS project."
  echo ""
  echo "Tips:"
  echo "  • Re-run this script after bumping WHISPER_VERSION."
  echo "  • Set WHISPER_MODELS to a space-separated list to download other quantized models."
  echo ""
}

main "$@"

