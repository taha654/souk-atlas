// Tests de la console sans serveur : une FAUSSE API (même interface que la
// vraie) enregistre les appels et renvoie des réponses préparées
#include "Console.hpp"
#include "Verif.hpp"

#include <cstdio>
#include <filesystem>
#include <sstream>
#include <unistd.h>

using namespace souk;

namespace {

class FausseApi : public ServiceApi {
public:
    std::vector<std::string> appels;
    std::vector<Json> corpsEnvoyes;
    std::map<std::string, Json> reponsesGet;
    int statutErreur = 0;   // != 0 : chaque appel lève ErreurApi

    Json get(const std::string& chemin) override {
        appels.push_back("GET " + chemin);
        if (statutErreur != 0) throw ErreurApi(statutErreur, "refusé");
        const auto it = reponsesGet.find(chemin);
        return it == reponsesGet.end() ? Json::objet() : it->second;
    }

    // Import : accepte tout sauf la catégorie "Inconnue", comme le ferait le serveur
    Json post(const std::string& chemin, const Json& corps) override {
        appels.push_back("POST " + chemin);
        corpsEnvoyes.push_back(corps);
        if (statutErreur != 0) throw ErreurApi(statutErreur, "refusé");
        Json reponse = Json::objet();
        Json resultats = Json::tableau();
        for (const Json& p : corps["produits"].elements()) {
            Json r = Json::objet();
            r["ligne"] = p["ligne"].nombre();
            r["ok"] = p.texteOu("categorie", "") != "Inconnue";
            if (r["ok"].booleen()) r["id"] = 1000 + p["ligne"].nombre();
            else r["erreur"] = "catégorie inconnue « Inconnue »";
            resultats.ajouter(std::move(r));
        }
        reponse["resultats"] = std::move(resultats);
        return reponse;
    }
};

struct Execution {
    int code;
    std::string sortie;
    std::string erreurs;
};

Execution lancer(FausseApi& api, const std::vector<std::string>& args) {
    std::ostringstream sortie;
    std::ostringstream erreurs;
    Contexte contexte{api, sortie, erreurs};
    const int code = Console().lancer(args, contexte);
    return {code, sortie.str(), erreurs.str()};
}

bool contient(const std::string& texte, const std::string& morceau) { return texte.find(morceau) != std::string::npos; }

}  // namespace

int main() {
    const auto dossier = std::filesystem::temp_directory_path() / ("souk-console-tests-" + std::to_string(::getpid()));
    std::filesystem::create_directories(dossier);
    const std::string csv = (dossier / "catalogue.csv").string();
    const std::string rapport = (dossier / "rapport.csv").string();

    // Catalogue de 7 lignes : 2 refusées localement, 1 par le "serveur", 4 importées
    std::string contenu = "nom;description;prix_ht;stock;categorie\n";
    for (int i = 1; i <= 4; ++i) contenu += "Produit " + std::to_string(i) + ";;10,50;5;Jouets\n";
    contenu += "X;;10;5;Jouets\n";                // nom trop court
    contenu += "Produit cher;;douze;5;Jouets\n";  // prix illisible
    contenu += "Produit égaré;;10;5;Inconnue\n";  // refusé par le serveur
    ecrireFichier(csv, contenu);

    // --- import-csv : lots, fusion des refus locaux et serveur, rapport, code 1
    FausseApi api;
    auto e = lancer(api, {"import-csv", csv, "--lot", "2", "--rapport", rapport});
    VERIFIER_EGAL(1, e.code);                                  // des lignes refusées → kPartiel
    VERIFIER_EGAL(3u, api.corpsEnvoyes.size());                // 5 lignes valides par lots de 2
    VERIFIER_EGAL(2u, api.corpsEnvoyes[0]["produits"].elements().size());
    VERIFIER_EGAL(std::string("10.50"), api.corpsEnvoyes[0]["produits"].elements()[0].texteOu("prix_ht", ""));
    VERIFIER(contient(e.sortie, "Lignes lues : 7 | importées : 4 | rejetées : 3"));
    VERIFIER(contient(e.sortie, "ligne 6 : nom de 3 à 200"));
    VERIFIER(contient(e.sortie, "ligne 7 : prix_ht invalide « douze »"));
    VERIFIER(contient(e.sortie, "ligne 8 : refusé par le serveur : catégorie inconnue"));
    const std::string r = lireFichier(rapport);
    VERIFIER(contient(r, "ligne;resultat;detail"));
    VERIFIER(contient(r, "2;IMPORTE;produit 1002"));
    VERIFIER(contient(r, "8;REJETE;refusé par le serveur"));

    // --essai : rien n'est envoyé
    FausseApi essai;
    e = lancer(essai, {"import-csv", csv, "--essai"});
    VERIFIER(essai.appels.empty());
    VERIFIER(contient(e.sortie, "valides : 5"));

    // Erreurs d'utilisation : code 2 et rappel de l'usage
    e = lancer(api, {"import-csv"});
    VERIFIER_EGAL(2, e.code);
    VERIFIER(contient(e.erreurs, "souk-console import-csv FICHIER.csv"));
    VERIFIER_EGAL(2, (lancer(api, {"import-csv", (dossier / "absent.csv").string()})).code);
    VERIFIER_EGAL(2, (lancer(api, {"import-csv", csv, "--lot", "500"})).code);
    VERIFIER_EGAL(2, (lancer(api, {"import-csv", csv, "--rapprot", "x.csv"})).code);   // faute de frappe détectée
    VERIFIER_EGAL(2, (lancer(api, {"inconnue"})).code);

    // Refus du serveur (jeton invalide) : code 3, message clair
    FausseApi refus;
    refus.statutErreur = 401;
    e = lancer(refus, {"import-csv", csv});
    VERIFIER_EGAL(3, e.code);
    VERIFIER(contient(e.erreurs, "HTTP 401"));

    // --- moderation
    FausseApi moderation;
    Json liste = Json::objet();
    Json signalements = Json::tableau();
    Json s = Json::objet();
    s["id"] = 12; s["type"] = "ANNONCE"; s["nb"] = 3; s["motif"] = "ARNAQUE"; s["cible"] = "iPhone à 500 DH";
    signalements.ajouter(s);
    liste["signalements"] = signalements;
    moderation.reponsesGet["/api/console/signalements?statut=OUVERT"] = liste;
    e = lancer(moderation, {"moderation", "liste"});
    VERIFIER_EGAL(0, e.code);
    VERIFIER(contient(e.sortie, "iPhone à 500 DH"));
    e = lancer(moderation, {"moderation", "approuver", "12"});
    VERIFIER_EGAL(std::string("POST /api/console/signalements/12"), moderation.appels.back());
    VERIFIER_EGAL(std::string("APPROUVER"), moderation.corpsEnvoyes.back().texteOu("decision", ""));
    VERIFIER_EGAL(2, (lancer(moderation, {"moderation", "approuver", "douze"})).code);
    VERIFIER_EGAL(2, (lancer(moderation, {"moderation", "supprimer", "12"})).code);

    // --- rapport : résumé à l'écran et CSV au format français
    FausseApi ventes;
    Json rap = Json::analyser(R"({"perimetre":"toutes les boutiques","total":{"nb_commandes":3,"ca_ht":12345.6,"panier_moyen_ttc":4938.24},
        "jours":[{"jour":"2026-01-01","nb_commandes":1,"ca_ht":100.5,"ca_cumule":100.5},
                 {"jour":"2026-01-02","nb_commandes":2,"ca_ht":12245.1,"ca_cumule":12345.6}],
        "meilleures_ventes":[{"rang":1,"produit":"Lampe","quantite":4}],"boutiques":[{"rang":1,"boutique":"Atlas","ca_ht":12345.6}]})");
    ventes.reponsesGet["/api/console/rapport?debut=2026-01-01&fin=2026-01-02"] = rap;
    const std::string sortieCsv = (dossier / "ventes.csv").string();
    e = lancer(ventes, {"rapport", "--debut", "2026-01-01", "--fin=2026-01-02", "--sortie", sortieCsv});
    VERIFIER_EGAL(0, e.code);
    VERIFIER(contient(e.sortie, "CA HT          : 12 345,60 MAD"));
    VERIFIER(contient(e.sortie, "1. Atlas"));
    const std::string v = lireFichier(sortieCsv);
    VERIFIER(contient(v, "jour;nb_commandes;ca_ht;ca_cumule\r\n2026-01-01;1;100,50;100,50\r\n"));
    VERIFIER(contient(v, "2026-01-02;2;12245,10;12345,60"));
    VERIFIER_EGAL(2, (lancer(ventes, {"rapport", "--debut", "01/01/2026"})).code);

    // --- utilitaires
    VERIFIER_EGAL(std::string("1 234 567,89"), montantFr(1234567.891));
    VERIFIER_EGAL(std::string("-0,50"), montantFr(-0.5));
    VERIFIER_EGAL(10u, dateDuJour().size());

    // Sans jeton : l'aide marche, les commandes expliquent quoi faire
    ApiSansJeton sansJeton;
    std::ostringstream o, err;
    Contexte c{sansJeton, o, err};
    VERIFIER_EGAL(0, (Console().lancer({"aide"}, c)));
    VERIFIER(contient(o.str(), "import-csv"));
    VERIFIER_EGAL(3, (Console().lancer({"moi"}, c)));
    VERIFIER(contient(err.str(), "SOUK_JETON"));

    std::filesystem::remove_all(dossier);
    return verif::bilan();
}
