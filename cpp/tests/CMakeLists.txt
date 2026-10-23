# Un exécutable par fichier de test ; CTest les lance tous (ctest --output-on-failure)
foreach(nom test_json test_texte_graphe test_risque test_actions)
    add_executable(${nom} ${nom}.cpp)
    target_link_libraries(${nom} PRIVATE souk_moteur)
    add_test(NAME ${nom} COMMAND ${nom})
endforeach()

# Tests du programme complet : stdin → stdout et codes de sortie
add_test(NAME moteur_bout_en_bout
         COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/test_moteur.sh $<TARGET_FILE:souk-moteur>)
