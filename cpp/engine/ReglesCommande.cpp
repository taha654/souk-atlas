#include "ReglesCommande.hpp"

#include <cmath>

namespace souk {

namespace {
std::string mad(double montant) { return std::to_string(std::lround(montant)) + " MAD"; }
}  // namespace

std::optional<Raison> RegleMontantInhabituel::evaluer(const ContexteCommande& c) const {
    if (c.commandesPrecedentes >= 2 && c.panierMoyen > 0 && c.totalTtc > 5 * c.panierMoyen) {
        return Raison{nom(), 25, mad(c.totalTtc) + ", plus de 5 fois le panier moyen du client (" + mad(c.panierMoyen) + ")"};
    }
    if (c.commandesPrecedentes == 0 && c.totalTtc > 10000) {
        return Raison{nom(), 20, "première commande de " + mad(c.totalTtc)};
    }
    return std::nullopt;
}

std::optional<Raison> RegleQuantiteElevee::evaluer(const ContexteCommande& c) const {
    if (c.quantiteMax >= 10) return Raison{nom(), 15, std::to_string(c.quantiteMax) + " exemplaires du même produit"};
    return std::nullopt;
}

std::optional<Raison> RegleRafaleCommandes::evaluer(const ContexteCommande& c) const {
    if (c.commandes24h >= 5) return Raison{nom(), 25, std::to_string(c.commandes24h) + " commandes en 24 h"};
    if (c.commandes24h >= 3) return Raison{nom(), 10, std::to_string(c.commandes24h) + " commandes en 24 h"};
    return std::nullopt;
}

std::optional<Raison> ReglePaiementLivraison::evaluer(const ContexteCommande& c) const {
    // Gros montant payé à la livraison : risque de refus du colis (frais de retour)
    if (c.modePaiement == "LIVRAISON" && c.totalTtc > 5000) {
        return Raison{nom(), 15, "paiement à la livraison de " + mad(c.totalTtc)};
    }
    return std::nullopt;
}

AnalyseurRisque<ContexteCommande> analyseurCommande() {
    AnalyseurRisque<ContexteCommande> analyseur;
    analyseur.ajouter(std::make_unique<RegleMontantInhabituel>())
        .ajouter(std::make_unique<RegleQuantiteElevee>())
        .ajouter(std::make_unique<RegleRafaleCommandes>())
        .ajouter(std::make_unique<ReglePaiementLivraison>())
        .ajouter(std::make_unique<RegleCompteRecent<ContexteCommande>>());
    return analyseur;
}

}  // namespace souk
