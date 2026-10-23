// =============================================================================
// Distance d'édition entre deux mots : le nombre minimal d'opérations
// (insertion, suppression, remplacement d'une lettre) pour passer de l'un à
// l'autre. "samsng" → "samsung" : 1 (insertion du "u").
//
// Programmation dynamique : d[i][j] = distance entre les i premières lettres
// de a et les j premières lettres de b. Chaque case ne dépend que de la ligne
// précédente : on garde 2 lignes (O(|b|) en mémoire) au lieu du tableau entier.
// Variante "avec transpositions" (Damerau, version OSA) : échanger deux
// lettres voisines ("smasung") coûte 1 au lieu de 2 ; il faut alors 3 lignes.
// =============================================================================
#pragma once

#include <string>
#include <string_view>

namespace souk {

std::size_t distanceLevenshtein(std::u32string_view a, std::u32string_view b, bool transpositions = true);

// Texte UTF-8 → points de code (un char32_t par caractère, accents compris)
std::u32string versCodePoints(std::string_view utf8);

}  // namespace souk
