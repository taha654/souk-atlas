// =============================================================================
// Sous-commandes de souk-console : patron de conception COMMANDE.
//
// Chaque sous-commande est une classe qui dérive de Commande et sait se
// décrire (nom, résumé, usage) et s'exécuter. La Console (Console.hpp) les
// range par nom : ajouter une sous-commande = écrire une classe et
// l'enregistrer, sans toucher au reste du programme.
// =============================================================================
#pragma once

#include "Api.hpp"

#include <map>
#include <optional>
#include <ostream>
#include <set>
#include <stdexcept>
#include <string>
#include <vector>

namespace souk {

// Codes de sortie (utilisables dans un script : "souk-console import-csv f.csv || echo raté")
enum CodeSortie : int {
    kSucces = 0,
    kPartiel = 1,      // terminé, mais des lignes ont été refusées
    kUsage = 2,        // mauvaise utilisation : arguments, fichier illisible
    kErreurApi = 3,    // réseau, authentification, refus du serveur
};

class ErreurUsage : public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};

// Ce que reçoit une commande : l'API et les flux de sortie (std::cout en vrai,
// des std::ostringstream dans les tests)
struct Contexte {
    ServiceApi& api;
    std::ostream& sortie;
    std::ostream& erreurs;
};

// Arguments d'une commande : positionnels, options "--nom valeur" ou "--nom=valeur",
// et drapeaux sans valeur ("--essai") déclarés à l'avance
class Arguments {
public:
    Arguments(const std::vector<std::string>& args, const std::set<std::string>& drapeaux = {});
    const std::vector<std::string>& positionnels() const noexcept { return positionnels_; }
    std::optional<std::string> option(const std::string& nom) const;
    bool drapeau(const std::string& nom) const { return drapeaux_.count(nom) > 0; }
    // Refuse les options inconnues (une faute de frappe ne doit pas passer inaperçue)
    void verifierOptions(const std::set<std::string>& connues) const;

private:
    std::vector<std::string> positionnels_;
    std::map<std::string, std::string> options_;
    std::set<std::string> drapeaux_;
};

class Commande {
public:
    virtual ~Commande() = default;
    virtual std::string nom() const = 0;
    virtual std::string resume() const = 0;   // une ligne, pour la liste des commandes
    virtual std::string usage() const = 0;    // aide détaillée
    virtual int executer(const std::vector<std::string>& args, Contexte& contexte) const = 0;
};

class CommandeMoi : public Commande {
public:
    std::string nom() const override { return "moi"; }
    std::string resume() const override { return "affiche le compte associé au jeton"; }
    std::string usage() const override;
    int executer(const std::vector<std::string>& args, Contexte& contexte) const override;
};

class CommandeCategories : public Commande {
public:
    std::string nom() const override { return "categories"; }
    std::string resume() const override { return "liste les catégories utilisables dans un CSV"; }
    std::string usage() const override;
    int executer(const std::vector<std::string>& args, Contexte& contexte) const override;
};

class CommandeImportCsv : public Commande {
public:
    std::string nom() const override { return "import-csv"; }
    std::string resume() const override { return "importe un catalogue CSV dans votre boutique (vendeur)"; }
    std::string usage() const override;
    int executer(const std::vector<std::string>& args, Contexte& contexte) const override;
};

class CommandeModeration : public Commande {
public:
    std::string nom() const override { return "moderation"; }
    std::string resume() const override { return "liste et traite les signalements (admin)"; }
    std::string usage() const override;
    int executer(const std::vector<std::string>& args, Contexte& contexte) const override;
};

class CommandeRapport : public Commande {
public:
    std::string nom() const override { return "rapport"; }
    std::string resume() const override { return "ventes d'une période, exportées en CSV"; }
    std::string usage() const override;
    int executer(const std::vector<std::string>& args, Contexte& contexte) const override;
};

// Utilitaires (exposés pour les tests)
std::string lireFichier(const std::string& chemin);              // lève ErreurUsage
void ecrireFichier(const std::string& chemin, const std::string& contenu);
std::string montantFr(double montant, bool separateurMilliers = true);   // 12345.6 → "12 345,60"
std::string dateDuJour(int decalageJours = 0);                    // "AAAA-MM-JJ"

}  // namespace souk
