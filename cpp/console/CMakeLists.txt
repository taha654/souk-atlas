# Outil d'administration en ligne de commande : parle au site par son API JSON
add_library(souk_console STATIC Socket.cpp ClientHttp.cpp ApiHttp.cpp Csv.cpp ImportCsv.cpp Commandes.cpp Console.cpp)
target_include_directories(souk_console PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(souk_console PUBLIC souk_commun)

add_executable(souk-console main.cpp)
target_link_libraries(souk-console PRIVATE souk_console)
install(TARGETS souk-console RUNTIME DESTINATION bin)
