// Règles du score de risque d'une petite annonce
#pragma once

#include "Regle.hpp"

#include <string>
#include <vector>

namespace souk {

struct ContexteAnnonce {
    std::string titre;
    std::string description;
    double prix = 0;
    double prixMedianCategorie = 0;   // médiane des annonces de la catégorie (0 = inconnue)
    int nbAnnoncesCategorie = 0;      // taille de l'échantillon de la médiane
    int annoncesAuteur24h = 0;        // annonces publiées par l'auteur sur 24 h
    Compte compte;
};

class RegleMotsSuspects : public Regle<ContexteAnnonce> {
public:
    // Expressions typiques des arnaques (paiement hors plateforme, urgence…)
    explicit RegleMotsSuspects(std::vector<std::string> expressions = expressionsParDefaut());
    std::string nom() const override { return "mots_suspects"; }
    std::optional<Raison> evaluer(const ContexteAnnonce& c) const override;
    static std::vector<std::string> expressionsParDefaut();

private:
    std::vector<std::string> expressions_;   // déjà normalisées
};

class ReglePrixAnormal : public Regle<ContexteAnnonce> {
public:
    std::string nom() const override { return "prix_anormal"; }
    std::optional<Raison> evaluer(const ContexteAnnonce& c) const override;
};

class RegleVolumeAnnonces : public Regle<ContexteAnnonce> {
public:
    std::string nom() const override { return "volume_inhabituel"; }
    std::optional<Raison> evaluer(const ContexteAnnonce& c) const override;
};

class RegleMajuscules : public Regle<ContexteAnnonce> {
public:
    std::string nom() const override { return "titre_criard"; }
    std::optional<Raison> evaluer(const ContexteAnnonce& c) const override;
};

class RegleCoordonnees : public Regle<ContexteAnnonce> {
public:
    std::string nom() const override { return "coordonnees"; }
    std::optional<Raison> evaluer(const ContexteAnnonce& c) const override;
};

// L'analyseur complet utilisé par le moteur
AnalyseurRisque<ContexteAnnonce> analyseurAnnonce();

}  // namespace souk
