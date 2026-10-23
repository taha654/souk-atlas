// La console : registre des sous-commandes (nom → objet) et point d'entrée
#pragma once

#include "Commandes.hpp"

#include <map>
#include <memory>

namespace souk {

class Console {
public:
    Console();   // enregistre toutes les sous-commandes connues
    void ajouter(std::unique_ptr<Commande> commande);

    // args : la ligne de commande SANS le nom du programme ; renvoie le code de sortie
    int lancer(const std::vector<std::string>& args, Contexte& contexte) const;

private:
    std::map<std::string, std::unique_ptr<Commande>> commandes_;

    void afficherAide(std::ostream& sortie) const;
};

// API utilisée quand SOUK_JETON n'est pas défini : chaque appel explique quoi faire
class ApiSansJeton : public ServiceApi {
public:
    Json get(const std::string&) override { refuser(); }
    Json post(const std::string&, const Json&) override { refuser(); }

private:
    [[noreturn]] static void refuser() {
        throw ErreurApi(401, "aucun jeton : créez-en un sur le site (Mon compte → Jetons d'accès), "
                             "puis « export SOUK_JETON=souk_… »");
    }
};

}  // namespace souk
