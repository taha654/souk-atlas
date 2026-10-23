<?php
declare(strict_types=1);

namespace App\Core;

/**
 * La requête HTTP reçue, lue une seule fois depuis les superglobales.
 * Le reste du code ne touche jamais directement $_GET, $_POST ou $_SERVER.
 */
final class Request
{
    /**
     * @param array<string, mixed> $query  paramètres de l'URL (?ville=Rabat)
     * @param array<string, mixed> $post   champs du formulaire
     */
    public function __construct(
        public readonly string $methode,
        public readonly string $chemin,
        public readonly array $query,
        public readonly array $post,
        public readonly string $ip,
        public readonly bool $https,
        /** @var array<string, string> en-têtes HTTP, noms en minuscules ("x-csrf-token") */
        public readonly array $entetes = [],
        /** @var array<string, mixed> fichiers envoyés ($_FILES) */
        public readonly array $fichiers = [],
    ) {
    }

    public static function depuisGlobales(): self
    {
        $chemin = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

        return new self(
            strtoupper($_SERVER['REQUEST_METHOD'] ?? 'GET'),
            rawurldecode($chemin),
            $_GET,
            $_POST,
            // REMOTE_ADDR est l'adresse qui a ouvert la connexion TCP : le client
            // ne peut pas la falsifier. On n'utilise PAS l'en-tête X-Forwarded-For,
            // que n'importe qui peut écrire (il servirait à contourner la limite par IP).
            $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0',
            // Même logique : HTTPS vu par Apache, pas l'en-tête X-Forwarded-Proto
            ($_SERVER['HTTPS'] ?? '') === 'on',
            self::entetesDepuisServeur($_SERVER),
            $_FILES,
        );
    }

    /**
     * PHP range les en-têtes dans $_SERVER sous la forme HTTP_X_CSRF_TOKEN :
     * on les remet sous leur nom habituel, en minuscules ("x-csrf-token").
     *
     * @param array<string, mixed> $serveur
     * @return array<string, string>
     */
    private static function entetesDepuisServeur(array $serveur): array
    {
        $entetes = [];
        foreach ($serveur as $cle => $valeur) {
            if (str_starts_with($cle, 'HTTP_') && is_string($valeur)) {
                $entetes[strtolower(str_replace('_', '-', substr($cle, 5)))] = $valeur;
            }
        }
        return $entetes;
    }

    /**
     * Un fichier envoyé (un seul, jamais un tableau de fichiers), ou null.
     *
     * @return array{name: string, type: string, tmp_name: string, error: int, size: int}|null
     */
    public function fichier(string $nom): ?array
    {
        $fichier = $this->fichiers[$nom] ?? null;
        // name="photo[]" donnerait des tableaux dans chaque clé : refusé
        if (!is_array($fichier) || !is_string($fichier['tmp_name'] ?? null) || !is_int($fichier['error'] ?? null)) {
            return null;
        }
        return $fichier;
    }

    public function entete(string $nom): ?string
    {
        return $this->entetes[strtolower($nom)] ?? null;
    }

    /** Champ de formulaire sous forme de texte nettoyé (jamais de tableau) */
    public function champ(string $nom): string
    {
        $valeur = $this->post[$nom] ?? '';
        return is_string($valeur) ? trim($valeur) : '';
    }

    /** Champ brut, sans trim : pour les mots de passe (les espaces comptent) */
    public function champBrut(string $nom): string
    {
        $valeur = $this->post[$nom] ?? '';
        return is_string($valeur) ? $valeur : '';
    }

    public function parametre(string $nom): string
    {
        $valeur = $this->query[$nom] ?? '';
        return is_string($valeur) ? trim($valeur) : '';
    }
}
