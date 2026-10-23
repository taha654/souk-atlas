// =============================================================================
// Score de risque : une hiérarchie de règles (polymorphisme).
//
//  Regle<C>              classe abstraite : "j'examine un contexte C et je
//                        donne éventuellement des points de risque"
//    ├─ RegleMotsSuspects, ReglePrixAnormal…   (annonces)
//    └─ RegleMontantInhabituel…                (commandes)
//  AnalyseurRisque<C>    possède une liste de règles (unique_ptr) et additionne
//
// Le paramètre de modèle C (le "contexte") permet d'écrire UNE fois l'analyseur
// et les règles communes (compte récent) pour les annonces ET les commandes.
// =============================================================================
#pragma once

#include <algorithm>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

namespace souk {

// Une raison qui explique une partie du score (affichée au modérateur)
struct Raison {
    std::string regle;    // identifiant stable, ex. "mots_suspects"
    int points;
    std::string detail;   // phrase lisible en français
};

struct ResultatRisque {
    int score = 0;                 // 0 à 100
    std::vector<Raison> raisons;

    // Mêmes seuils que PKG_ANNONCE.c_seuil_moderation (60) côté Oracle
    std::string niveau() const { return score >= 60 ? "ELEVE" : score >= 30 ? "MOYEN" : "FAIBLE"; }
};

template <typename Contexte>
class Regle {
public:
    virtual ~Regle() = default;   // destructeur virtuel : indispensable pour détruire via un pointeur de base
    virtual std::string nom() const = 0;
    // std::nullopt : la règle ne trouve rien à redire
    virtual std::optional<Raison> evaluer(const Contexte& contexte) const = 0;
};

template <typename Contexte>
class AnalyseurRisque {
public:
    // L'analyseur devient propriétaire de la règle (RAII : détruite avec lui)
    AnalyseurRisque& ajouter(std::unique_ptr<Regle<Contexte>> regle) {
        regles_.push_back(std::move(regle));
        return *this;
    }

    ResultatRisque analyser(const Contexte& contexte) const {
        ResultatRisque resultat;
        for (const auto& regle : regles_) {
            // Appel virtuel : c'est la règle concrète qui répond
            if (auto raison = regle->evaluer(contexte)) {
                resultat.score += raison->points;
                resultat.raisons.push_back(std::move(*raison));
            }
        }
        resultat.score = std::clamp(resultat.score, 0, 100);
        // Les raisons les plus lourdes d'abord
        std::stable_sort(resultat.raisons.begin(), resultat.raisons.end(),
                         [](const Raison& a, const Raison& b) { return a.points > b.points; });
        return resultat;
    }

    std::size_t nbRegles() const noexcept { return regles_.size(); }

private:
    std::vector<std::unique_ptr<Regle<Contexte>>> regles_;
};

// -----------------------------------------------------------------------------
// Profil du compte, commun aux deux contextes
struct Compte {
    double ancienneteJours = 365;   // âge du compte
};

// Règle générique : fonctionne avec tout contexte qui possède un membre "compte"
template <typename Contexte>
class RegleCompteRecent : public Regle<Contexte> {
public:
    std::string nom() const override { return "compte_recent"; }
    std::optional<Raison> evaluer(const Contexte& c) const override {
        if (c.compte.ancienneteJours < 2) return Raison{nom(), 20, "compte créé il y a moins de 2 jours"};
        if (c.compte.ancienneteJours < 7) return Raison{nom(), 10, "compte créé il y a moins d'une semaine"};
        return std::nullopt;
    }
};

}  // namespace souk
