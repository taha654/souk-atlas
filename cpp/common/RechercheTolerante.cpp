#include "RechercheTolerante.hpp"

#include "Levenshtein.hpp"
#include "Texte.hpp"

#include <algorithm>
#include <limits>

namespace souk {

namespace {
std::vector<std::u32string> motsNormalises(const std::string& texte) {
    std::vector<std::u32string> resultat;
    for (const std::string& mot : texte::mots(texte::normaliser(texte))) resultat.push_back(versCodePoints(mot));
    return resultat;
}
}  // namespace

std::size_t IndexTolerant::tolerance(std::size_t longueur) {
    if (longueur <= 3) return 0;
    if (longueur <= 5) return 1;
    if (longueur <= 9) return 2;
    return 3;
}

void IndexTolerant::ajouter(int id, const std::string& titre) {
    entrees_.push_back({id, titre, motsNormalises(titre)});
}

std::vector<ResultatTolerant> IndexTolerant::rechercher(const std::string& requete, std::size_t limite) const {
    const std::vector<std::u32string> cherches = motsNormalises(requete);
    std::vector<ResultatTolerant> resultats;
    if (cherches.empty()) return resultats;

    for (const Entree& entree : entrees_) {
        std::size_t total = 0;
        bool tousTrouves = true;
        for (std::size_t k = 0; k < cherches.size() && tousTrouves; ++k) {
            const std::u32string& cherche = cherches[k];
            const bool enCoursDeFrappe = k + 1 == cherches.size() && cherche.size() >= 3;
            std::size_t meilleure = std::numeric_limits<std::size_t>::max();
            for (const std::u32string& mot : entree.mots) {
                meilleure = std::min(meilleure, distanceLevenshtein(cherche, mot));
                if (enCoursDeFrappe && mot.size() > cherche.size()) {
                    // Comparaison avec le début du mot ("sams" contre "sams|ung")
                    meilleure = std::min(meilleure, distanceLevenshtein(cherche, std::u32string_view(mot).substr(0, cherche.size())));
                }
                if (meilleure == 0) break;
            }
            if (meilleure > tolerance(cherche.size())) tousTrouves = false;
            else total += meilleure;
        }
        if (tousTrouves) resultats.push_back({entree.id, entree.titre, static_cast<int>(total)});
    }

    std::stable_sort(resultats.begin(), resultats.end(), [](const ResultatTolerant& a, const ResultatTolerant& b) {
        if (a.distance != b.distance) return a.distance < b.distance;
        return a.titre.size() < b.titre.size();
    });
    if (resultats.size() > limite) resultats.resize(limite);
    return resultats;
}

}  // namespace souk
