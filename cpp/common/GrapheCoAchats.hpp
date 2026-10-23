// =============================================================================
// GrapheCoAchats : graphe pondéré « achetés ensemble ».
//
//  - un SOMMET par produit, avec le nombre de paniers qui le contiennent ;
//  - une ARÊTE entre deux produits achetés dans le même panier, pondérée par
//    le nombre de paniers où ils apparaissent ensemble.
//
// Score de recommandation = similarité cosinus :
//      ensemble(a, b) / √(paniers(a) × paniers(b))
// Il vaut 1 si a et b sont toujours achetés ensemble, et pénalise les produits
// très populaires qui apparaissent "avec tout" (sinon ils seraient recommandés partout).
// =============================================================================
#pragma once

#include <cstddef>
#include <unordered_map>
#include <vector>

namespace souk {

struct Recommandation {
    int produit;
    double score;      // 0 à 1
    int communs;       // nombre de paniers communs
};

class GrapheCoAchats {
public:
    // Un panier = les produits d'un même achat (les doublons sont ignorés)
    void ajouterPanier(std::vector<int> produits);

    // Meilleures recommandations pour un produit (score décroissant), en
    // ignorant les paires vues moins de supportMin fois (trop peu fiables)
    std::vector<Recommandation> recommandations(int produit, std::size_t limite, int supportMin) const;

    // Tous les produits vus, triés (sortie déterministe)
    std::vector<int> produits() const;

    std::size_t nbPaniers() const noexcept { return nbPaniers_; }
    int occurrences(int produit) const;
    int ensemble(int a, int b) const;

private:
    std::size_t nbPaniers_ = 0;
    std::unordered_map<int, int> occurrences_;                          // sommets
    std::unordered_map<int, std::unordered_map<int, int>> voisins_;     // arêtes (dans les deux sens)
};

}  // namespace souk
