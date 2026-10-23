<?php
declare(strict_types=1);

namespace App\Core;

use App\Core\Erreurs\ErreurBaseDeDonnees;
use App\Core\Erreurs\ErreurMetier;

/**
 * Accès à Oracle via OCI8.
 *
 * Trois règles, appliquées ici une fois pour toutes :
 *  1. Variables liées partout (oci_bind_by_name) : une valeur n'est JAMAIS
 *     collée dans le texte SQL, donc pas d'injection SQL possible.
 *  2. OCI_NO_AUTO_COMMIT : rien n'est validé tant que valider() n'est pas
 *     appelé. Sans valider(), oci_close() (ou la fin du script) annule tout.
 *  3. Une erreur -20xxx d'un package devient une ErreurMetier (message pour
 *     l'utilisateur) ; toute autre erreur Oracle devient une ErreurBaseDeDonnees.
 */
final class Database
{
    /** @var resource */
    private $connexion;

    /** @param array{utilisateur: string, mot_de_passe: string, dsn: string} $config */
    public function __construct(array $config)
    {
        // AL32UTF8 : l'encodage UTF-8 d'Oracle, pour que les accents arrivent intacts
        $connexion = @oci_connect($config['utilisateur'], $config['mot_de_passe'], $config['dsn'], 'AL32UTF8');
        if ($connexion === false) {
            $erreur = oci_error();
            throw new ErreurBaseDeDonnees('Connexion à Oracle impossible : ' . ($erreur['message'] ?? '?'));
        }
        $this->connexion = $connexion;

        // Formats fixés pour la session, quel que soit le réglage du serveur :
        // dates ISO (lisibles par PHP) et point décimal ("12.5" et non "12,5",
        // que PHP convertirait en 12 !)
        $p = [];
        $this->appeler("BEGIN
            EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_DATE_FORMAT = ''YYYY-MM-DD HH24:MI:SS''';
            EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS = ''.,''';
        END;", $p);
    }

    /**
     * Indique à Oracle QUI agit (l'id de l'utilisateur du site). Les triggers
     * d'audit le relisent avec SYS_CONTEXT('USERENV', 'CLIENT_IDENTIFIER').
     */
    public function definirUtilisateur(?int $idUtilisateur): void
    {
        oci_set_client_identifier($this->connexion, $idUtilisateur === null ? '' : (string) $idUtilisateur);
    }

    /**
     * SELECT renvoyant toutes les lignes (tableaux associatifs, colonnes en MAJUSCULES).
     *
     * @param array<string, scalar|null> $parametres  [':email' => '…'] ou ['email' => '…']
     * @return list<array<string, mixed>>
     */
    public function lignes(string $sql, array $parametres = []): array
    {
        $requete = $this->executer($sql, $parametres);
        oci_fetch_all($requete, $lignes, 0, -1, OCI_FETCHSTATEMENT_BY_ROW | OCI_ASSOC);
        oci_free_statement($requete);
        return $lignes;
    }

    /**
     * SELECT renvoyant au plus une ligne (null si aucune).
     *
     * @param array<string, scalar|null> $parametres
     * @return array<string, mixed>|null
     */
    public function ligne(string $sql, array $parametres = []): ?array
    {
        $requete = $this->executer($sql, $parametres);
        $ligne = oci_fetch_assoc($requete);
        oci_free_statement($requete);
        return $ligne === false ? null : $ligne;
    }

    /** Première colonne de la première ligne (pratique pour COUNT(*) ou une fonction) */
    public function valeur(string $sql, array $parametres = []): mixed
    {
        $ligne = $this->ligne($sql, $parametres);
        return $ligne === null ? null : reset($ligne);
    }

    /**
     * Bloc PL/SQL (appel de package) avec paramètres en entrée et en sortie.
     * Les paramètres sont passés PAR RÉFÉRENCE : après l'appel, $parametres
     * contient les valeurs écrites par Oracle dans les paramètres OUT.
     *
     *   $p = ['email' => $email, 'id' => null];
     *   $db->appeler('BEGIN pkg_utilisateur.creer_compte(:email, …, :id); END;', $p);
     *   $id = (int) $p['id'];
     *
     * @param array<string, scalar|null> $parametres
     */
    public function appeler(string $plsql, array &$parametres = []): void
    {
        oci_free_statement($this->executer($plsql, $parametres));
    }

    public function valider(): void
    {
        oci_commit($this->connexion);
    }

    public function annuler(): void
    {
        oci_rollback($this->connexion);
    }

    /**
     * @param array<string, scalar|null> $parametres
     * @return resource
     */
    private function executer(string $sql, array &$parametres)
    {
        $requete = oci_parse($this->connexion, $sql);
        if ($requete === false) {
            throw new ErreurBaseDeDonnees('SQL invalide : ' . (oci_error($this->connexion)['message'] ?? '?'));
        }

        foreach ($parametres as $nom => &$valeur) {
            // Longueur maximale 4000 : nécessaire pour qu'Oracle puisse écrire
            // dans les paramètres OUT ; sans effet gênant pour les paramètres IN
            oci_bind_by_name($requete, ':' . ltrim((string) $nom, ':'), $valeur, 4000);
        }
        unset($valeur); // casse la référence laissée par le foreach

        if (!@oci_execute($requete, OCI_NO_AUTO_COMMIT)) {
            $erreur = oci_error($requete) ?: ['code' => 0, 'message' => 'erreur inconnue'];
            oci_free_statement($requete);
            throw self::traduire((int) $erreur['code'], (string) $erreur['message']);
        }
        return $requete;
    }

    /**
     * Oracle renvoie par exemple :
     *   "ORA-20008: Un compte existe déjà avec l'email x.\nORA-06512: at …"
     * On garde la première ligne, sans le préfixe "ORA-20008: ".
     */
    public static function traduire(int $code, string $message): \RuntimeException
    {
        if ($code >= 20000 && $code <= 20999) {
            $premiereLigne = strtok($message, "\n") ?: $message;
            $texte = preg_replace('/^ORA-\d+:\s*/', '', $premiereLigne) ?? $premiereLigne;
            return new ErreurMetier(-$code, trim($texte));
        }
        return new ErreurBaseDeDonnees('ORA-' . str_pad((string) $code, 5, '0', STR_PAD_LEFT) . ' ' . $message);
    }
}
