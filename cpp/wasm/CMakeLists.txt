# Module WebAssembly (compilé seulement avec Emscripten : ./cpp/construire_wasm.sh)
add_executable(souk_wasm liaisons.cpp)
target_link_libraries(souk_wasm PRIVATE souk_commun)
# Produit souk.js (code de chargement) + souk.wasm (le code compilé)
set_target_properties(souk_wasm PROPERTIES OUTPUT_NAME "souk" SUFFIX ".js")
target_link_options(souk_wasm PRIVATE
    -lembind                              # liaisons C++ ↔ JavaScript
    -sMODULARIZE=1 -sEXPORT_ES6=1         # module ES : import creerModuleSouk from '…/souk.js'
    -sEXPORT_NAME=creerModuleSouk
    -sENVIRONMENT=web                     # pas de code pour Node.js ni les workers
    -sFILESYSTEM=0                        # pas de système de fichiers simulé : module plus léger
    -sALLOW_MEMORY_GROWTH=1               # une photo de 12 Mpx occupe 48 Mo de pixels
    -sMAXIMUM_MEMORY=1gb
    -sDYNAMIC_EXECUTION=0                 # aucun eval()/new Function() : compatible avec notre CSP
    -sEXPORTED_FUNCTIONS=_malloc,_free
    -sEXPORTED_RUNTIME_METHODS=HEAPU8)
