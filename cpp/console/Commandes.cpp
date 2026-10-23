#include "Commandes.hpp"

#include "Csv.hpp"
#include "ImportCsv.hpp"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cmath>
#include <ctime>
#include <fstream>
#include <iomanip>
#include <sstream>

namespace souk {

// ============================================================================= Arguments

Arguments::Arguments(const std::vector<std::string>& args, const std::set<std::string>& drapeaux) {
    for (std::size_t i = 0; i < args.size(); ++i) {
        const std::string& a = args[i];
        if (a.rfind("--", 0) != 0 || a.size() == 2) {
            positionnels_.push_back(a);
            continue;
        }
        const std::size_t egal = a.find('=');
        const std::string nom = a.substr(2, egal == std::string::npos ? std::string::npos : egal - 2);
        if (egal != std::string::npos) {
            options_[nom] = a.substr(egal + 1);
        } else if (drapeaux.count(nom) > 0) {
            drapeaux_.insert(nom);
        } else if (i + 1 < args.size()) {
            options_[nom] = args[++i];
        } else {
            throw ErreurUsage("valeur manquante après --" + nom);
        }
    }
}

std::optional<std::string> Arguments::option(const std::string& nom) const {
    const auto it = options_.find(nom);
    return it == options_.end() ? std::nullopt : std::optional<std::string>(it->second);
}

void Arguments::verifierOptions(const std::set<std::string>& connues) const {
    for (const auto& [nom, valeur] : options_) {
        if (connues.count(nom) == 0) throw ErreurUsage("option inconnue : --" + nom);
    }
}

// ============================================================================= utilitaires

std::string lireFichier(const std::string& chemin) {
    std::ifstream fichier(chemin, std::ios::binary);   // binaire : les octets UTF-8 et \r\n restent intacts
    if (!fichier) throw ErreurUsage("impossible de lire le fichier « " + chemin + " »");
    std::ostringstream contenu;
    contenu << fichier.rdbuf();
    return contenu.str();
}

void ecrireFichier(const std::string& chemin, const std::string& contenu) {
    std::ofstream fichier(chemin, std::ios::binary | std::ios::trunc);
    if (!fichier || !(fichier << contenu)) throw ErreurUsage("impossible d'écrire le fichier « " + chemin + " »");
}

std::string montantFr(double montant, bool separateurMilliers) {
    const long long centimes = std::llround(montant * 100);
    std::string entiere = std::to_string(std::llabs(centimes) / 100);
    if (separateurMilliers) {
        for (int i = static_cast<int>(entiere.size()) - 3; i > 0; i -= 3) entiere.insert(static_cast<std::size_t>(i), " ");
    }
    std::ostringstream texte;
    texte << (centimes < 0 ? "-" : "") << entiere << ',' << std::setw(2) << std::setfill('0') << std::llabs(centimes) % 100;
    return texte.str();
}

std::string dateDuJour(int decalageJours) {
    const auto instant = std::chrono::system_clock::now() + std::chrono::hours(24 * decalageJours);
    const std::time_t t = std::chrono::system_clock::to_time_t(instant);
    std::tm local{};
    localtime_r(&t, &local);   // version "réentrante" (sûre) de localtime
    char texte[11];
    std::strftime(texte, sizeof texte, "%Y-%m-%d", &local);
    return texte;
}

namespace {
bool dateValide(const std::string& d) {
    return d.size() == 10 && d[4] == '-' && d[7] == '-'
           && std::all_of(d.begin(), d.end(), [](char c) { return std::isdigit(static_cast<unsigned char>(c)) || c == '-'; });
}
long entierPositif(const std::string& texte, const std::string& quoi) {
    if (texte.empty() || texte.size() > 9 || texte.find_first_not_of("0123456789") != std::string::npos) {
        throw ErreurUsage(quoi + " invalide : « " + texte + " »");
    }
    return std::stol(texte);
}
}  // namespace

// ============================================================================= moi

std::string CommandeMoi::usage() const { return "souk-console moi"; }

int CommandeMoi::executer(const std::vector<std::string>& args, Contexte& c) const {
    if (!args.empty()) throw ErreurUsage("cette commande ne prend pas d'argument");
    const Json moi = c.api.get("/api/console/moi");
    c.sortie << "Connecté en tant que " << moi.texteOu("nom", "?") << " (" << moi.texteOu("role", "?") << ")\n";
    if (moi["boutique"].estObjet()) {
        c.sortie << "Boutique : " << moi["boutique"].texteOu("nom", "?") << " — " << moi["boutique"].texteOu("statut", "?") << '\n';
    }
    return kSucces;
}

// ============================================================================= categories

std::string CommandeCategories::usage() const {
    return "souk-console categories\n  Les noms affichés s'utilisent tels quels dans la colonne « categorie » du CSV\n"
           "  (majuscules et accents facultatifs).";
}

int CommandeCategories::executer(const std::vector<std::string>& args, Contexte& c) const {
    if (!args.empty()) throw ErreurUsage("cette commande ne prend pas d'argument");
    // La réponse est gardée dans une variable : "get(…)[…].elements()" référencerait
    // l'intérieur d'un objet temporaire, détruit à la fin de l'instruction
    const Json reponse = c.api.get("/api/console/categories");
    for (const Json& cat : reponse["categories"].elements()) {
        const int niveau = static_cast<int>(cat.nombreOu("niveau", 1));
        c.sortie << std::string(static_cast<std::size_t>(2 * (niveau - 1)), ' ') << cat.texteOu("nom", "?")
                 << "  (" << static_cast<long>(cat.nombreOu("id", 0)) << ")\n";
    }
    return kSucces;
}

// ============================================================================= import-csv

std::string CommandeImportCsv::usage() const {
    return "souk-console import-csv FICHIER.csv [--rapport ERREURS.csv] [--essai] [--lot N]\n"
           "  Colonnes : nom;description;prix_ht;stock;categorie (séparateur ; ou ,)\n"
           "  --essai    vérifie le fichier sans rien envoyer\n"
           "  --rapport  écrit le résultat de chaque ligne (OK ou motif du refus) dans un CSV\n"
           "  --lot N    produits envoyés par requête (1 à 100, 50 par défaut)";
}

int CommandeImportCsv::executer(const std::vector<std::string>& args, Contexte& c) const {
    const Arguments a(args, {"essai"});
    a.verifierOptions({"rapport", "lot"});
    if (a.positionnels().size() != 1) throw ErreurUsage("indiquez un (seul) fichier CSV");
    const long tailleLot = a.option("lot") ? entierPositif(*a.option("lot"), "taille de lot") : 50;
    if (tailleLot < 1 || tailleLot > 100) throw ErreurUsage("--lot doit être entre 1 et 100");

    LectureCatalogue lecture;
    try {
        lecture = lireCatalogue(lireFichier(a.positionnels()[0]));
    } catch (const ErreurCsv& e) {
        throw ErreurUsage(std::string("CSV illisible, ") + e.what());
    }

    // Résultat de chaque ligne, rangé par numéro de ligne (std::map : trié)
    std::map<std::size_t, std::string> refus;
    std::map<std::size_t, long> importes;
    for (const RejetLigne& r : lecture.rejets) refus[r.ligne] = r.message;

    if (!a.drapeau("essai")) {
        const auto& produits = lecture.produits;
        for (std::size_t debut = 0; debut < produits.size(); debut += static_cast<std::size_t>(tailleLot)) {
            const std::size_t fin = std::min(produits.size(), debut + static_cast<std::size_t>(tailleLot));
            Json lot = Json::tableau();
            for (std::size_t i = debut; i < fin; ++i) {
                Json p = Json::objet();
                p["ligne"] = static_cast<long>(produits[i].ligne);
                p["nom"] = produits[i].nom;
                p["description"] = produits[i].description;
                p["prix_ht"] = produits[i].prixHt;
                p["stock"] = std::to_string(produits[i].stock);
                p["categorie"] = produits[i].categorie;
                lot.ajouter(std::move(p));
            }
            Json corps = Json::objet();
            corps["produits"] = std::move(lot);
            Json reponse;
            try {
                reponse = c.api.post("/api/console/produits", corps);
            } catch (const ErreurApi&) {
                // Les lots précédents sont déjà enregistrés : on le dit avant d'abandonner
                if (!importes.empty()) c.erreurs << importes.size() << " produit(s) déjà importé(s) avant l'erreur.\n";
                throw;
            }
            for (const Json& r : reponse["resultats"].elements()) {
                const auto ligne = static_cast<std::size_t>(r.nombreOu("ligne", 0));
                if (r["ok"].estBooleen() && r["ok"].booleen()) {
                    importes[ligne] = static_cast<long>(r.nombreOu("id", 0));
                } else {
                    refus[ligne] = "refusé par le serveur : " + r.texteOu("erreur", "?");
                }
            }
            c.sortie << "  … " << fin << " / " << produits.size() << " ligne(s) valide(s) envoyée(s)\n";
        }
    }

    c.sortie << "Lignes lues : " << lecture.nbLignes
             << (a.drapeau("essai") ? " | valides : " + std::to_string(lecture.produits.size())
                                    : " | importées : " + std::to_string(importes.size()))
             << " | rejetées : " << refus.size() << '\n';
    for (const auto& [ligne, message] : refus) c.sortie << "  ligne " << ligne << " : " << message << '\n';

    if (const auto chemin = a.option("rapport")) {
        std::string rapport = ligneCsv({"ligne", "resultat", "detail"}) + "\r\n";
        std::map<std::size_t, std::vector<std::string>> lignes;
        for (const auto& [ligne, id] : importes) lignes[ligne] = {std::to_string(ligne), "IMPORTE", "produit " + std::to_string(id)};
        for (const auto& [ligne, message] : refus) lignes[ligne] = {std::to_string(ligne), "REJETE", message};
        if (a.drapeau("essai")) {
            for (const auto& p : lecture.produits) lignes[p.ligne] = {std::to_string(p.ligne), "VALIDE", "non envoyé (--essai)"};
        }
        for (const auto& [ligne, champs] : lignes) rapport += ligneCsv(champs) + "\r\n";
        ecrireFichier(*chemin, rapport);
        c.sortie << "Rapport écrit dans " << *chemin << '\n';
    }
    return refus.empty() ? kSucces : kPartiel;
}

// ============================================================================= moderation

std::string CommandeModeration::usage() const {
    return "souk-console moderation liste [--statut OUVERT|APPROUVE|REJETE]\n"
           "souk-console moderation approuver ID   (le contenu signalé est retiré)\n"
           "souk-console moderation rejeter ID     (le signalement est classé, le contenu reste)";
}

int CommandeModeration::executer(const std::vector<std::string>& args, Contexte& c) const {
    const Arguments a(args);
    a.verifierOptions({"statut"});
    const auto& p = a.positionnels();
    if (p.empty()) throw ErreurUsage("action attendue : liste, approuver ou rejeter");

    if (p[0] == "liste") {
        const std::string statut = a.option("statut").value_or("OUVERT");
        const Json reponse = c.api.get("/api/console/signalements?statut=" + encoderUrl(statut));
        const auto& liste = reponse["signalements"].elements();
        if (liste.empty()) {
            c.sortie << "Aucun signalement " << statut << ".\n";
            return kSucces;
        }
        c.sortie << std::left << std::setw(6) << "ID" << std::setw(9) << "TYPE" << std::setw(5) << "NB"
                 << std::setw(14) << "MOTIF" << "CIBLE\n";
        for (const Json& s : liste) {
            c.sortie << std::setw(6) << static_cast<long>(s.nombreOu("id", 0)) << std::setw(9) << s.texteOu("type", "?")
                     << std::setw(5) << static_cast<long>(s.nombreOu("nb", 0)) << std::setw(14) << s.texteOu("motif", "?")
                     << s.texteOu("cible", "") << '\n';
        }
        return kSucces;
    }
    if (p[0] != "approuver" && p[0] != "rejeter") throw ErreurUsage("action inconnue : « " + p[0] + " »");
    if (p.size() != 2) throw ErreurUsage("indiquez l'identifiant du signalement");
    const long id = entierPositif(p[1], "identifiant");
    Json corps = Json::objet();
    corps["decision"] = p[0] == "approuver" ? "APPROUVER" : "REJETER";
    c.api.post("/api/console/signalements/" + std::to_string(id), corps);
    c.sortie << "Signalement " << id << (p[0] == "approuver" ? " approuvé : le contenu a été retiré.\n"
                                                             : " rejeté : le contenu reste en ligne.\n");
    return kSucces;
}

// ============================================================================= rapport

std::string CommandeRapport::usage() const {
    return "souk-console rapport [--debut AAAA-MM-JJ] [--fin AAAA-MM-JJ] [--sortie VENTES.csv]\n"
           "  Par défaut : les 30 derniers jours. Vendeur : sa boutique ; admin : tout le site.\n"
           "  Le CSV (séparateur ; et virgule décimale) s'ouvre directement dans Excel ou LibreOffice.";
}

int CommandeRapport::executer(const std::vector<std::string>& args, Contexte& c) const {
    const Arguments a(args);
    a.verifierOptions({"debut", "fin", "sortie"});
    if (!a.positionnels().empty()) throw ErreurUsage("argument inattendu : « " + a.positionnels()[0] + " »");
    const std::string fin = a.option("fin").value_or(dateDuJour());
    const std::string debut = a.option("debut").value_or(dateDuJour(-29));
    if (!dateValide(debut) || !dateValide(fin)) throw ErreurUsage("dates attendues au format AAAA-MM-JJ");

    const Json r = c.api.get("/api/console/rapport?debut=" + encoderUrl(debut) + "&fin=" + encoderUrl(fin));
    const Json& total = r["total"];
    c.sortie << "Ventes du " << debut << " au " << fin << " (" << r.texteOu("perimetre", "") << ")\n"
             << "  Commandes      : " << static_cast<long>(total.nombreOu("nb_commandes", 0)) << '\n'
             << "  CA HT          : " << montantFr(total.nombreOu("ca_ht", 0)) << " MAD\n"
             << "  Panier moyen   : " << montantFr(total.nombreOu("panier_moyen_ttc", 0)) << " MAD TTC\n";

    if (!r["meilleures_ventes"].elements().empty()) {
        c.sortie << "Meilleures ventes :\n";
        for (const Json& m : r["meilleures_ventes"].elements()) {
            c.sortie << "  " << std::setw(2) << static_cast<long>(m.nombreOu("rang", 0)) << ". " << m.texteOu("produit", "?")
                     << " — " << static_cast<long>(m.nombreOu("quantite", 0)) << " vendu(s)\n";
        }
    }
    if (!r["boutiques"].elements().empty()) {
        c.sortie << "Boutiques :\n";
        for (const Json& b : r["boutiques"].elements()) {
            c.sortie << "  " << std::setw(2) << static_cast<long>(b.nombreOu("rang", 0)) << ". " << b.texteOu("boutique", "?")
                     << " — " << montantFr(b.nombreOu("ca_ht", 0)) << " MAD HT\n";
        }
    }

    if (const auto chemin = a.option("sortie")) {
        // Séparateur ";" et virgule décimale : le format qu'attend un tableur réglé en français
        std::string csv = ligneCsv({"jour", "nb_commandes", "ca_ht", "ca_cumule"}) + "\r\n";
        for (const Json& j : r["jours"].elements()) {
            csv += ligneCsv({j.texteOu("jour", ""), std::to_string(static_cast<long>(j.nombreOu("nb_commandes", 0))),
                             montantFr(j.nombreOu("ca_ht", 0), false), montantFr(j.nombreOu("ca_cumule", 0), false)}) + "\r\n";
        }
        ecrireFichier(*chemin, csv);
        c.sortie << r["jours"].elements().size() << " jour(s) exporté(s) dans " << *chemin << '\n';
    }
    return kSucces;
}

}  // namespace souk
