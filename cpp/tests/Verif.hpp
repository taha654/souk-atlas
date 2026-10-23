// =============================================================================
// Mini-cadre de tests (même esprit que PKG_TEST côté Oracle) :
//   VERIFIER(condition)          → OK / ÉCHEC avec le fichier et la ligne
//   VERIFIER_EGAL(attendu, obtenu)
//   VERIFIER_EXCEPTION(expr, Type)
//   return bilan();              → code de sortie 1 s'il y a un échec (CTest le voit)
// =============================================================================
#pragma once

#include <iostream>
#include <sstream>
#include <string>

namespace verif {

inline int& reussis() { static int n = 0; return n; }
inline int& echecs() { static int n = 0; return n; }

inline void noter(bool ok, const std::string& description, const char* fichier, int ligne) {
    if (ok) {
        ++reussis();
        std::cout << "OK      " << description << '\n';
    } else {
        ++echecs();
        std::cout << "ÉCHEC   " << description << "  (" << fichier << ':' << ligne << ")\n";
    }
}

template <typename A, typename B>
void noterEgal(const A& attendu, const B& obtenu, const std::string& description, const char* fichier, int ligne) {
    const bool ok = attendu == obtenu;
    std::ostringstream texte;
    texte << description;
    if (!ok) texte << " — attendu : " << attendu << ", obtenu : " << obtenu;
    noter(ok, texte.str(), fichier, ligne);
}

inline int bilan() {
    std::cout << "\n" << reussis() << " OK, " << echecs() << " ÉCHEC\n";
    return echecs() == 0 ? 0 : 1;
}

}  // namespace verif

#define VERIFIER(condition) verif::noter(static_cast<bool>(condition), #condition, __FILE__, __LINE__)
#define VERIFIER_EGAL(attendu, obtenu) verif::noterEgal((attendu), (obtenu), #obtenu " == " #attendu, __FILE__, __LINE__)
#define VERIFIER_EXCEPTION(expression, Type)                                          \
    do {                                                                              \
        bool leve = false;                                                            \
        try { (void)(expression); } catch (const Type&) { leve = true; }              \
        verif::noter(leve, #expression " lève " #Type, __FILE__, __LINE__);           \
    } while (0)
