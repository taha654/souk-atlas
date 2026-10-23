# Bibliothèque (testable) + petit exécutable qui ne fait que lire/écrire
add_library(souk_moteur STATIC Actions.cpp ReglesAnnonce.cpp ReglesCommande.cpp)
target_include_directories(souk_moteur PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(souk_moteur PUBLIC souk_commun)

add_executable(souk-moteur main.cpp)
target_link_libraries(souk-moteur PRIVATE souk_moteur)
install(TARGETS souk-moteur RUNTIME DESTINATION bin)
