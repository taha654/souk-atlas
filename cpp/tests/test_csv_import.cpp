#include "Csv.hpp"
#include "ImportCsv.hpp"
#include "Verif.hpp"

using namespace souk;

int main() {
    // --- Lecteur CSV (RFC 4180)
    LecteurCsv l("\xEF\xBB\xBFnom;prix\r\n\"Lampe \"\"Atlas\"\"\";12,5\r\n\r\n\"Sur deux\nlignes\";\"a;b\"\n");
    EnregistrementCsv e;
    VERIFIER_EGAL(';', l.separateur());
    VERIFIER(l.suivant(e));
    VERIFIER_EGAL(std::string("nom"), e.champs[0]);   // BOM retiré
    VERIFIER(l.suivant(e));
    VERIFIER_EGAL(std::string("Lampe \"Atlas\""), e.champs[0]);
    VERIFIER_EGAL(std::string("12,5"), e.champs[1]);    // la virgule n'est pas le séparateur ici
    VERIFIER_EGAL(2u, e.ligne);
    VERIFIER(l.suivant(e));                              // ligne vide ignorée
    VERIFIER_EGAL(4u, e.ligne);
    VERIFIER_EGAL(std::string("Sur deux\nlignes"), e.champs[0]);
    VERIFIER_EGAL(std::string("a;b"), e.champs[1]);
    VERIFIER(!l.suivant(e));

    LecteurCsv virgules("a,b;c,d\n1,2\n");
    VERIFIER_EGAL(',', virgules.separateur());           // détection automatique
    LecteurCsv vide("a;;c\n");
    vide.suivant(e);
    VERIFIER_EGAL(3u, e.champs.size());                  // champ vide conservé
    LecteurCsv ouvert("a;\"jamais fermé\n");
    VERIFIER_EXCEPTION(ouvert.suivant(e), ErreurCsv);

    // Écriture : guillemets seulement si nécessaire, aller-retour exact
    VERIFIER_EGAL(std::string("simple"), champCsv("simple"));
    VERIFIER_EGAL(std::string("\"a;b\""), champCsv("a;b"));
    VERIFIER_EGAL(std::string("\"dit \"\"oui\"\"\""), champCsv("dit \"oui\""));
    LecteurCsv retour(ligneCsv({"x;y", "il a dit \"non\"", "deux\nlignes"}) + "\n");
    retour.suivant(e);
    VERIFIER_EGAL(std::string("il a dit \"non\""), e.champs[1]);
    VERIFIER_EGAL(std::string("deux\nlignes"), e.champs[2]);

    // --- Prix
    VERIFIER_EGAL(std::string("1299.90"), normaliserPrix("1 299,90").value_or("?"));
    VERIFIER_EGAL(std::string("1299.90"), normaliserPrix("1\xC2\xA0" "299,90").value_or("?"));   // espace insécable
    VERIFIER_EGAL(std::string("15"), normaliserPrix("15").value_or("?"));
    VERIFIER(!normaliserPrix("0").has_value());
    VERIFIER(!normaliserPrix("-5").has_value());
    VERIFIER(!normaliserPrix("12,345").has_value());     // 3 décimales
    VERIFIER(!normaliserPrix("12,").has_value());
    VERIFIER(!normaliserPrix("abc").has_value());
    VERIFIER(!normaliserPrix("1.2.3").has_value());
    VERIFIER(!normaliserPrix("20000000").has_value());   // au-delà du maximum
    VERIFIER_EGAL(3u, longueurUtf8("été"));

    // --- Catalogue complet : lignes valides et rejets avec numéro de ligne
    const auto lecture = lireCatalogue(
        "Nom;Catégorie;Prix_HT;Stock;Description\n"
        "Lampe berbère;Décoration & meubles;349,00;12;Cuivre martelé\n"
        "Tapis;Décoration & meubles;899;3;Trop court ? Non : 5 lettres\n"
        "TV;Électroménager;abc;-2;\n"
        "Bouilloire;Électroménager;199\n"
        "Pouf en cuir;;250;4;\n"
        "\"Plateau \"\"Fès\"\"\";Décoration & meubles;\"1 250,50\";0;\"Laiton ; fait main\"\n");
    VERIFIER_EGAL(6u, lecture.nbLignes);
    VERIFIER_EGAL(3u, lecture.produits.size());
    VERIFIER_EGAL(3u, lecture.rejets.size());
    VERIFIER_EGAL(std::string("Décoration & meubles"), lecture.produits[0].categorie);   // colonnes dans le désordre
    VERIFIER_EGAL(std::string("349.00"), lecture.produits[0].prixHt);
    VERIFIER_EGAL(std::string("Plateau \"Fès\""), lecture.produits[2].nom);
    VERIFIER_EGAL(std::string("1250.50"), lecture.produits[2].prixHt);
    VERIFIER_EGAL(7u, lecture.produits[2].ligne);
    VERIFIER_EGAL(4u, lecture.rejets[0].ligne);
    VERIFIER(lecture.rejets[0].message.find("nom de 3 à 200") != std::string::npos);    // toutes les erreurs de la ligne
    VERIFIER(lecture.rejets[0].message.find("prix_ht invalide « abc »") != std::string::npos);
    VERIFIER(lecture.rejets[0].message.find("stock invalide « -2 »") != std::string::npos);
    VERIFIER(lecture.rejets[1].message.find("3 colonne(s) au lieu de 5") != std::string::npos);
    VERIFIER(lecture.rejets[2].message.find("catégorie manquante") != std::string::npos);

    VERIFIER_EXCEPTION(lireCatalogue("nom;prix\nA;1\n"), ErreurCsv);   // colonnes obligatoires absentes
    VERIFIER_EXCEPTION(lireCatalogue(""), ErreurCsv);
    return verif::bilan();
}
