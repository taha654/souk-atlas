#include "GrapheCoAchats.hpp"

#include <algorithm>
#include <cmath>

namespace souk {

void GrapheCoAchats::ajouterPanier(std::vector<int> produits) {
    // Tri + unique : un produit en 2 exemplaires ne compte qu'une fois par panier
    std::sort(produits.begin(), produits.end());
    produits.erase(std::unique(produits.begin(), produits.end()), produits.end());
    if (produits.empty()) return;

    ++nbPaniers_;
    for (std::size_t i = 0; i < produits.size(); ++i) {
        ++occurrences_[produits[i]];
        for (std::size_t j = i + 1; j < produits.size(); ++j) {
            ++voisins_[produits[i]][produits[j]];
            ++voisins_[produits[j]][produits[i]];
        }
    }
}

std::vector<Recommandation> GrapheCoAchats::recommandations(int produit, std::size_t limite, int supportMin) const {
    std::vector<Recommandation> resultat;
    const auto it = voisins_.find(produit);
    if (it == voisins_.end()) return resultat;

    const double paniersProduit = occurrences(produit);
    for (const auto& [voisin, communs] : it->second) {
        if (communs < supportMin) continue;
        const double score = communs / std::sqrt(paniersProduit * occurrences(voisin));
        resultat.push_back({voisin, score, communs});
    }
    // Score décroissant ; à égalité, l'id le plus petit (résultat reproductible)
    auto ordre = [](const Recommandation& x, const Recommandation& y) {
        return x.score != y.score ? x.score > y.score : x.produit < y.produit;
    };
    // partial_sort : on ne trie que les "limite" premiers, inutile de tout trier
    const std::size_t n = std::min(limite, resultat.size());
    std::partial_sort(resultat.begin(), resultat.begin() + static_cast<std::ptrdiff_t>(n), resultat.end(), ordre);
    resultat.resize(n);
    return resultat;
}

std::vector<int> GrapheCoAchats::produits() const {
    std::vector<int> liste;
    liste.reserve(occurrences_.size());
    for (const auto& [produit, nb] : occurrences_) liste.push_back(produit);
    std::sort(liste.begin(), liste.end());
    return liste;
}

int GrapheCoAchats::occurrences(int produit) const {
    const auto it = occurrences_.find(produit);
    return it == occurrences_.end() ? 0 : it->second;
}

int GrapheCoAchats::ensemble(int a, int b) const {
    const auto it = voisins_.find(a);
    if (it == voisins_.end()) return 0;
    const auto jt = it->second.find(b);
    return jt == it->second.end() ? 0 : jt->second;
}

}  // namespace souk
