add_library(souk_commun STATIC Json.cpp Texte.cpp GrapheCoAchats.cpp
                               Levenshtein.cpp RechercheTolerante.cpp Redimensionnement.cpp)
target_include_directories(souk_commun PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
