// =============================================================================
// Réduction d'une image (pixels RGBA, 4 octets par pixel) par MOYENNE DE ZONE.
//
// Pour réduire 4000 px en 1600 px, chaque pixel d'arrivée couvre 2,5 pixels
// de départ : on fait la moyenne de cette zone, en pondérant les pixels
// coupés en deux. C'est plus net et sans "crénelage" que l'interpolation
// bilinéaire du navigateur, qui ne regarde que 4 pixels voisins et "saute"
// les autres quand on réduit beaucoup.
// Calcul séparable : d'abord horizontalement (une ligne à la fois), puis
// verticalement en accumulant les lignes : la mémoire reste petite.
// =============================================================================
#pragma once

#include <cstdint>
#include <utility>

namespace souk {

// Dimensions réduites pour tenir dans un carré cote×cote, proportions gardées
// (jamais agrandies) : 4000×3000 dans 1600 → 1600×1200
std::pair<int, int> dimensionsReduites(int largeur, int hauteur, int cote);

// source : largeur×hauteur×4 octets ; destination : nouvelleLargeur×nouvelleHauteur×4 octets.
// Lève std::invalid_argument si les dimensions sont incohérentes ou si on demande d'agrandir.
void reduireRgba(const std::uint8_t* source, int largeur, int hauteur,
                 std::uint8_t* destination, int nouvelleLargeur, int nouvelleHauteur);

}  // namespace souk
