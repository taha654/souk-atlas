// =============================================================================
// souk-moteur : lit UNE requête JSON sur l'entrée standard, écrit UNE réponse
// JSON sur la sortie standard.
//
// Codes de sortie (lus par app/Services/CppEngine.php) :
//   0 : succès            {"ok": true, ...}
//   2 : requête invalide  {"ok": false, "erreur": "..."}
//   3 : erreur interne    {"ok": false, "erreur": "..."}
//
// Exemple : echo '{"action":"risque_annonce","annonce":{"titre":"Vélo","prix":800}}' | souk-moteur
// =============================================================================
#include "Actions.hpp"

#include <iostream>
#include <iterator>
#include <string>

namespace {

// Au-delà, on refuse : protège la mémoire si PHP envoie par erreur un énorme texte
constexpr std::size_t kTailleMaxEntree = 16 * 1024 * 1024;

int repondreErreur(const std::string& message, int code) {
    souk::Json reponse = souk::Json::objet();
    reponse["ok"] = false;
    reponse["erreur"] = message;
    std::cout << reponse.serialiser() << '\n';
    return code;
}

}  // namespace

int main() {
    std::ios::sync_with_stdio(false);   // entrées-sorties plus rapides (pas de mélange avec printf)

    std::string entree;
    char tampon[65536];
    while (std::cin.read(tampon, sizeof tampon) || std::cin.gcount() > 0) {
        entree.append(tampon, static_cast<std::size_t>(std::cin.gcount()));
        if (entree.size() > kTailleMaxEntree) return repondreErreur("entrée trop volumineuse", 2);
    }

    try {
        const souk::Json requete = souk::Json::analyser(entree);
        const souk::Registre registre;
        std::cout << registre.traiter(requete).serialiser() << '\n';
        return 0;
    } catch (const souk::ErreurJson& e) {
        return repondreErreur(std::string("JSON invalide : ") + e.what(), 2);
    } catch (const souk::RequeteInvalide& e) {
        return repondreErreur(e.what(), 2);
    } catch (const std::exception& e) {
        // Exception non prévue (mémoire, accès JSON d'un mauvais type…)
        return repondreErreur(std::string("erreur interne : ") + e.what(), 3);
    }
}
