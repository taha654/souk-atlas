# =============================================================================
# Souk Atlas — composants C++ (C++17, CMake)
#   common/  : bibliothèque partagée (JSON, texte, graphe)
#   engine/  : moteur appelé par PHP (JSON sur stdin → JSON sur stdout)
#   console/ : outil d'administration en ligne de commande (API JSON du site)
#   tests/   : tests unitaires et d'intégration (CTest)
# Construction (dans Docker) : ./cpp/construire.sh
# =============================================================================
cmake_minimum_required(VERSION 3.16)
project(SoukAtlasCpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Avertissements stricts : un avertissement est souvent un bug en devenir
add_compile_options(-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wno-sign-conversion)

# Option des tests : AddressSanitizer + UndefinedBehaviorSanitizer détectent à
# l'exécution les accès mémoire invalides, fuites et comportements indéfinis
option(SOUK_SANITIZERS "Compiler avec ASan et UBSan" OFF)
if(SOUK_SANITIZERS)
    add_compile_options(-fsanitize=address,undefined -fno-omit-frame-pointer)
    add_link_options(-fsanitize=address,undefined)
endif()

enable_testing()
add_subdirectory(common)
add_subdirectory(engine)
add_subdirectory(console)
add_subdirectory(tests)
