<?php
declare(strict_types=1);

namespace App\Core;

/**
 * Réponse HTTP construite par un contrôleur, puis envoyée par le contrôleur frontal.
 * Les contrôleurs n'appellent jamais header() ou echo eux-mêmes : une réponse est
 * une valeur qu'on peut inspecter (et tester) avant de l'envoyer.
 */
final class Response
{
    /** @param array<string, string> $entetes */
    public function __construct(
        public readonly string $corps = '',
        public readonly int $statut = 200,
        public readonly array $entetes = [],
    ) {
    }

    public static function html(string $corps, int $statut = 200): self
    {
        return new self($corps, $statut, ['Content-Type' => 'text/html; charset=UTF-8']);
    }

    /** Redirection 303 : après un POST, le navigateur refait un GET (pas de renvoi du formulaire) */
    public static function redirection(string $url, int $statut = 303): self
    {
        return new self('', $statut, ['Location' => $url]);
    }

    public static function json(mixed $donnees, int $statut = 200): self
    {
        return new self(
            json_encode($donnees, JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR),
            $statut,
            ['Content-Type' => 'application/json; charset=UTF-8'],
        );
    }

    /** Copie de la réponse avec un en-tête en plus (l'objet reste immuable) */
    public function avecEntete(string $nom, string $valeur): self
    {
        return new self($this->corps, $this->statut, [$nom => $valeur] + $this->entetes);
    }

    public function envoyer(): void
    {
        http_response_code($this->statut);
        foreach ($this->entetes as $nom => $valeur) {
            header($nom . ': ' . $valeur);
        }
        echo $this->corps;
    }
}
