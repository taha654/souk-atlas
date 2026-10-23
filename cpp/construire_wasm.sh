#!/usr/bin/env bash
# =============================================================================
# Compile le module WebAssembly avec Emscripten (dans Docker) et copie le
# résultat dans public/assets/wasm/ (souk.js + souk.wasm, versionnés dans git
# pour que le site marche sans installer Emscripten).
#   ./cpp/construire_wasm.sh
# Premier lancement : Emscripten compile aussi sa bibliothèque standard
# (quelques minutes), gardée ensuite dans cpp/build-wasm/cache.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

IMAGE=emscripten/emsdk:3.1.74   # version figée : même résultat sur toutes les machines
mkdir -p build-wasm/cache
docker run --rm -u "$(id -u):$(id -g)" -e EM_CACHE=/src/build-wasm/cache -v "$PWD":/src -w /src "$IMAGE" sh -c "
    emcmake cmake -S . -B build-wasm -DCMAKE_BUILD_TYPE=Release > /dev/null &&
    cmake --build build-wasm -j \$(nproc)"
install -m 644 build-wasm/wasm/souk.js build-wasm/wasm/souk.wasm ../public/assets/wasm/
ls -l ../public/assets/wasm/
