#include "Console.hpp"

#include "Socket.hpp"

namespace souk {

Console::Console() {
    ajouter(std::make_unique<CommandeMoi>());
    ajouter(std::make_unique<CommandeCategories>());
    ajouter(std::make_unique<CommandeImportCsv>());
    ajouter(std::make_unique<CommandeModeration>());
    ajouter(std::make_unique<CommandeRapport>());
}

void Console::ajouter(std::unique_ptr<Commande> commande) {
    const std::string nom = commande->nom();
    commandes_[nom] = std::move(commande);
}

void Console::afficherAide(std::ostream& sortie) const {
    sortie << "Utilisation : souk-console COMMANDE [arguments]\n\nCommandes :\n";
    for (const auto& [nom, commande] : commandes_) {
        sortie << "  " << nom << std::string(nom.size() < 12 ? 12 - nom.size() : 1, ' ') << commande->resume() << '\n';
    }
    sortie << "  aide        aide d'une commande : souk-console aide import-csv\n\n"
              "Variables d'environnement :\n"
              "  SOUK_JETON  jeton d'accès (Mon compte → Jetons d'accès sur le site)\n"
              "  SOUK_URL    adresse du site (http://localhost par défaut)\n";
}

int Console::lancer(const std::vector<std::string>& args, Contexte& c) const {
    if (args.empty() || args[0] == "aide" || args[0] == "--help" || args[0] == "-h") {
        if (args.size() >= 2) {
            const auto it = commandes_.find(args[1]);
            if (it == commandes_.end()) {
                c.erreurs << "Commande inconnue : « " << args[1] << " »\n";
                return kUsage;
            }
            c.sortie << it->second->usage() << '\n';
            return kSucces;
        }
        afficherAide(c.sortie);
        return args.empty() ? kUsage : kSucces;
    }

    const auto it = commandes_.find(args[0]);
    if (it == commandes_.end()) {
        c.erreurs << "Commande inconnue : « " << args[0] << " ». Tapez « souk-console aide ».\n";
        return kUsage;
    }
    const std::vector<std::string> reste(args.begin() + 1, args.end());
    try {
        return it->second->executer(reste, c);   // appel virtuel : la bonne sous-commande s'exécute
    } catch (const ErreurUsage& e) {
        c.erreurs << "Erreur : " << e.what() << "\n\n" << it->second->usage() << '\n';
        return kUsage;
    } catch (const ErreurApi& e) {
        c.erreurs << "Le site a refusé la demande";
        if (e.statut() != 0) c.erreurs << " (HTTP " << e.statut() << ")";
        c.erreurs << " : " << e.what() << '\n';
        return kErreurApi;
    } catch (const ErreurReseau& e) {
        c.erreurs << "Site injoignable : " << e.what() << " (vérifiez SOUK_URL et que le site est démarré)\n";
        return kErreurApi;
    } catch (const std::runtime_error& e) {
        // Réponse HTTP mal formée, JSON d'un type inattendu…
        c.erreurs << "Erreur : " << e.what() << '\n';
        return kErreurApi;
    }
}

}  // namespace souk
