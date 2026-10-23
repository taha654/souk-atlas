#include "Json.hpp"
#include "Verif.hpp"

using souk::ErreurJson;
using souk::Json;

int main() {
    // Lecture
    const Json j = Json::analyser(R"( {"a": 1, "b": [true, false, null], "c": "x\"y", "d": -2.5e2, "e": {}} )");
    VERIFIER(j.estObjet());
    VERIFIER_EGAL(1.0, j["a"].nombre());
    VERIFIER_EGAL(3u, j["b"].elements().size());
    VERIFIER(j["b"].elements()[0].booleen());
    VERIFIER(j["b"].elements()[2].estNul());
    VERIFIER_EGAL(std::string("x\"y"), j["c"].texte());
    VERIFIER_EGAL(-250.0, j["d"].nombre());
    VERIFIER(j["e"].estObjet());
    VERIFIER(j["absent"].estNul());
    VERIFIER_EGAL(7.0, j.nombreOu("absent", 7));
    VERIFIER_EGAL(std::string("défaut"), j.texteOu("a", "défaut"));   // "a" n'est pas un texte

    // Unicode : é = é (2 octets UTF-8), paire de substitution = emoji (4 octets)
    VERIFIER_EGAL(std::string("é"), Json::analyser(R"("é")").texte());
    VERIFIER_EGAL(std::string("\xF0\x9F\x98\x80"), Json::analyser(R"("😀")").texte());
    VERIFIER_EGAL(std::string("Fès"), Json::analyser("\"Fès\"").texte());

    // Écriture : clés triées, entiers sans décimales, échappements
    Json o = Json::objet();
    o["z"] = 12;
    o["a"] = "l'été \"chaud\"\n";
    o["m"] = 0.25;
    o["t"] = Json::tableau();
    o["t"].ajouter(nullptr);
    o["t"].ajouter(false);
    VERIFIER_EGAL(std::string(R"({"a":"l'été \"chaud\"\n","m":0.25,"t":[null,false],"z":12})"), o.serialiser());

    // Aller-retour
    const std::string texte = R"({"liste":[1,2.5,"trois",{"quatre":[]}],"vide":""})";
    VERIFIER_EGAL(texte, Json::analyser(texte).serialiser());

    // Erreurs détectées
    VERIFIER_EXCEPTION(Json::analyser(""), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser("{"), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser("[1,]"), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser("{\"a\" 1}"), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser("01"), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser("tru"), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser("\"non fermé"), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser("1 2"), ErreurJson);
    VERIFIER_EXCEPTION(Json::analyser(std::string(1000, '[')), ErreurJson);   // trop profond, pas de plantage
    VERIFIER_EXCEPTION(j["c"].nombre(), std::runtime_error);                 // mauvais type

    try {
        Json::analyser("[1, x]");
    } catch (const ErreurJson& e) {
        VERIFIER_EGAL(4u, e.position());
    }
    return verif::bilan();
}
