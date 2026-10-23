// =============================================================================
// Outils de texte : minuscules sans accents (même idée que la colonne virtuelle
// nom_recherche côté Oracle), découpage en mots, comptages.
// Les textes sont en UTF-8 : un "é" occupe 2 octets (0xC3 0xA9).
// =============================================================================
#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace souk::texte {

// "Téléphone ÉTÉ à Fès" → "telephone ete a fes"
std::string normaliser(std::string_view texte);

// Mots (lettres et chiffres) d'un texte déjà normalisé
std::vector<std::string> mots(std::string_view normalise);

// Vrai si l'expression (normalisée, éventuellement de plusieurs mots) apparaît
// comme suite de mots entiers : "virement" trouve "par virement", pas "virements"
bool contientExpression(std::string_view normalise, std::string_view expression);

// Part de lettres majuscules parmi les lettres ASCII (0 à 1) : "URGENT !!!" → 1
double partDeMajuscules(std::string_view texte);

}  // namespace souk::texte
