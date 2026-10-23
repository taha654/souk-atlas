// Règles du score de risque d'une commande de la marketplace
#pragma once

#include "Regle.hpp"

#include <string>

namespace souk {

struct ContexteCommande {
    double totalTtc = 0;
    int quantiteMax = 0;              // plus grande quantité sur une ligne
    std::string modePaiement;         // "CARTE" ou "LIVRAISON"
    int commandesPrecedentes = 0;     // commandes passées avant celle-ci
    double panierMoyen = 0;           // montant moyen de ces commandes
    int commandes24h = 0;             // commandes du client sur 24 h (celle-ci comprise)
    Compte compte;
};

class RegleMontantInhabituel : public Regle<ContexteCommande> {
public:
    std::string nom() const override { return "montant_inhabituel"; }
    std::optional<Raison> evaluer(const ContexteCommande& c) const override;
};

class RegleQuantiteElevee : public Regle<ContexteCommande> {
public:
    std::string nom() const override { return "quantite_elevee"; }
    std::optional<Raison> evaluer(const ContexteCommande& c) const override;
};

class RegleRafaleCommandes : public Regle<ContexteCommande> {
public:
    std::string nom() const override { return "volume_inhabituel"; }
    std::optional<Raison> evaluer(const ContexteCommande& c) const override;
};

class ReglePaiementLivraison : public Regle<ContexteCommande> {
public:
    std::string nom() const override { return "paiement_livraison"; }
    std::optional<Raison> evaluer(const ContexteCommande& c) const override;
};

AnalyseurRisque<ContexteCommande> analyseurCommande();

}  // namespace souk
