// =============================================================================
// Lecture et validation d'un catalogue CSV avant import.
//
// Colonnes (dans n'importe quel ordre, noms sans accents ni majuscules) :
//   nom ; description (facultative) ; prix_ht ; stock ; categorie
// Les erreurs détectables sans le serveur (prix illisible, stock négatif,
// colonnes manquantes…) sont signalées ici ; le serveur revalide TOUT de
// toute façon (catégorie existante, règles du package PL/SQL) : la console
// n'est qu'un client, on ne lui fait pas confiance.
// =============================================================================
#pragma once

#include <optional>
#include <string>
#include <vector>

namespace souk {

struct ProduitImporte {
    std::size_t ligne = 0;
    std::string nom;
    std::string description;
    std::string prixHt;     // normalisé : "1299.90"
    long stock = 0;
    std::string categorie;  // nom ou identifiant, résolu par le serveur
};

struct RejetLigne {
    std::size_t ligne;
    std::string message;
};

struct LectureCatalogue {
    std::vector<ProduitImporte> produits;   // lignes valides, à envoyer
    std::vector<RejetLigne> rejets;         // lignes refusées localement
    std::size_t nbLignes = 0;               // lignes de données lues (hors en-tête)
};

// Lève ErreurCsv si l'en-tête est inutilisable ou si un guillemet n'est pas refermé
LectureCatalogue lireCatalogue(const std::string& texte);

// "1 299,90" → "1299.90" ; nullopt si ce n'est pas un prix valide (> 0, 2 décimales au plus)
std::optional<std::string> normaliserPrix(const std::string& texte);

// Nombre de caractères d'un texte UTF-8 (et non d'octets : "é" compte pour 1)
std::size_t longueurUtf8(const std::string& texte);

}  // namespace souk
