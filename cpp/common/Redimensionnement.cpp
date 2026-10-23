#include "Redimensionnement.hpp"

#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>

namespace souk {

std::pair<int, int> dimensionsReduites(int largeur, int hauteur, int cote) {
    if (largeur <= 0 || hauteur <= 0 || cote <= 0) throw std::invalid_argument("dimensions invalides");
    if (largeur <= cote && hauteur <= cote) return {largeur, hauteur};
    const double facteur = static_cast<double>(cote) / std::max(largeur, hauteur);
    return {std::max(1, static_cast<int>(std::lround(largeur * facteur))),
            std::max(1, static_cast<int>(std::lround(hauteur * facteur)))};
}

namespace {

// Pour un pixel d'arrivée : les pixels de départ qu'il recouvre et leur poids
struct Contribution {
    int premier;                  // premier pixel de départ
    std::vector<float> poids;     // un poids par pixel de départ, somme = 1
};

std::vector<Contribution> contributions(int tailleDepart, int tailleArrivee) {
    const double echelle = static_cast<double>(tailleDepart) / tailleArrivee;   // >= 1 : réduction
    std::vector<Contribution> resultat(static_cast<std::size_t>(tailleArrivee));
    for (int i = 0; i < tailleArrivee; ++i) {
        const double debut = i * echelle;           // zone couverte : [debut, fin[
        const double fin = (i + 1) * echelle;
        Contribution& c = resultat[static_cast<std::size_t>(i)];
        c.premier = static_cast<int>(debut);
        const int dernier = std::min(tailleDepart - 1, static_cast<int>(std::ceil(fin)) - 1);
        for (int s = c.premier; s <= dernier; ++s) {
            // Part du pixel s (intervalle [s, s+1[) qui tombe dans la zone
            const double couvert = std::min<double>(fin, s + 1) - std::max<double>(debut, s);
            c.poids.push_back(static_cast<float>(couvert / echelle));
        }
    }
    return resultat;
}

}  // namespace

void reduireRgba(const std::uint8_t* source, int largeur, int hauteur,
                 std::uint8_t* destination, int nouvelleLargeur, int nouvelleHauteur) {
    if (source == nullptr || destination == nullptr || largeur <= 0 || hauteur <= 0
        || nouvelleLargeur <= 0 || nouvelleHauteur <= 0) {
        throw std::invalid_argument("image ou dimensions invalides");
    }
    if (nouvelleLargeur > largeur || nouvelleHauteur > hauteur) {
        throw std::invalid_argument("cette fonction réduit, elle n'agrandit pas");
    }
    const auto horizontales = contributions(largeur, nouvelleLargeur);
    const auto verticales = contributions(hauteur, nouvelleHauteur);
    const auto nl = static_cast<std::size_t>(nouvelleLargeur);

    std::vector<float> ligneReduite(nl * 4);   // une ligne de départ, réduite horizontalement
    std::vector<float> accumulateur(nl * 4);   // somme pondérée des lignes pour la ligne d'arrivée

    for (int y = 0; y < nouvelleHauteur; ++y) {
        std::fill(accumulateur.begin(), accumulateur.end(), 0.0f);
        const Contribution& cv = verticales[static_cast<std::size_t>(y)];
        for (std::size_t k = 0; k < cv.poids.size(); ++k) {
            const std::uint8_t* ligne = source + static_cast<std::size_t>(cv.premier + static_cast<int>(k))
                                                     * static_cast<std::size_t>(largeur) * 4;
            // 1. Réduction horizontale de cette ligne
            for (std::size_t x = 0; x < nl; ++x) {
                const Contribution& ch = horizontales[x];
                float r = 0, v = 0, b = 0, a = 0;
                for (std::size_t m = 0; m < ch.poids.size(); ++m) {
                    const std::uint8_t* p = ligne + static_cast<std::size_t>(ch.premier + static_cast<int>(m)) * 4;
                    r += p[0] * ch.poids[m];
                    v += p[1] * ch.poids[m];
                    b += p[2] * ch.poids[m];
                    a += p[3] * ch.poids[m];
                }
                ligneReduite[x * 4] = r;
                ligneReduite[x * 4 + 1] = v;
                ligneReduite[x * 4 + 2] = b;
                ligneReduite[x * 4 + 3] = a;
            }
            // 2. Ajout pondéré à la ligne d'arrivée (réduction verticale)
            for (std::size_t i = 0; i < nl * 4; ++i) accumulateur[i] += ligneReduite[i] * cv.poids[k];
        }
        std::uint8_t* sortie = destination + static_cast<std::size_t>(y) * nl * 4;
        for (std::size_t i = 0; i < nl * 4; ++i) {
            sortie[i] = static_cast<std::uint8_t>(std::clamp(std::lround(accumulateur[i]), 0L, 255L));
        }
    }
}

}  // namespace souk
