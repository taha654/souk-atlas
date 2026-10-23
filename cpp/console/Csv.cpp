#include "Csv.hpp"

namespace souk {

LecteurCsv::LecteurCsv(std::string texte, char separateur) : texte_(std::move(texte)), separateur_(separateur) {
    if (texte_.rfind("\xEF\xBB\xBF", 0) == 0) pos_ = 3;   // BOM UTF-8
    if (separateur_ == 0) {
        // Le séparateur le plus fréquent sur la première ligne (hors guillemets)
        int pointsVirgules = 0;
        int virgules = 0;
        bool guillemets = false;
        for (std::size_t i = pos_; i < texte_.size() && (guillemets || texte_[i] != '\n'); ++i) {
            if (texte_[i] == '"') guillemets = !guillemets;
            else if (!guillemets && texte_[i] == ';') ++pointsVirgules;
            else if (!guillemets && texte_[i] == ',') ++virgules;
        }
        separateur_ = virgules > pointsVirgules ? ',' : ';';
    }
}

bool LecteurCsv::suivant(EnregistrementCsv& enregistrement) {
    // Lignes vides (y compris "\r\n" seul) : ignorées
    while (pos_ < texte_.size() && (texte_[pos_] == '\n' || texte_[pos_] == '\r')) {
        if (texte_[pos_] == '\n') ++ligne_;
        ++pos_;
    }
    if (pos_ >= texte_.size()) return false;

    enregistrement.ligne = ligne_;
    enregistrement.champs.clear();
    std::string champ;
    bool entreGuillemets = false;
    bool champCite = false;   // le champ a commencé par un guillemet

    // Automate à deux états : dans ou hors des guillemets
    while (pos_ < texte_.size()) {
        const char c = texte_[pos_++];
        if (entreGuillemets) {
            if (c == '"') {
                if (pos_ < texte_.size() && texte_[pos_] == '"') {   // "" = un guillemet littéral
                    champ += '"';
                    ++pos_;
                } else {
                    entreGuillemets = false;
                }
            } else {
                if (c == '\n') ++ligne_;
                champ += c;
            }
        } else if (c == '"' && champ.empty() && !champCite) {
            entreGuillemets = true;
            champCite = true;
        } else if (c == separateur_) {
            enregistrement.champs.push_back(std::move(champ));
            champ.clear();
            champCite = false;
        } else if (c == '\n' || c == '\r') {
            if (c == '\r' && pos_ < texte_.size() && texte_[pos_] == '\n') ++pos_;
            ++ligne_;
            enregistrement.champs.push_back(std::move(champ));
            return true;
        } else {
            champ += c;
        }
    }
    if (entreGuillemets) throw ErreurCsv("guillemet ouvert jamais refermé", enregistrement.ligne);
    enregistrement.champs.push_back(std::move(champ));
    return true;
}

std::string champCsv(const std::string& valeur, char separateur) {
    if (valeur.find_first_of(std::string("\"\r\n") + separateur) == std::string::npos) return valeur;
    std::string resultat = "\"";
    for (const char c : valeur) {
        if (c == '"') resultat += '"';
        resultat += c;
    }
    return resultat + '"';
}

std::string ligneCsv(const std::vector<std::string>& champs, char separateur) {
    std::string ligne;
    for (std::size_t i = 0; i < champs.size(); ++i) {
        if (i > 0) ligne += separateur;
        ligne += champCsv(champs[i], separateur);
    }
    return ligne;
}

}  // namespace souk
