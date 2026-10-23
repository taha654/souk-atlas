<?php
declare(strict_types=1);

namespace App\Core\Erreurs;

/**
 * Erreur métier levée par un package PL/SQL avec RAISE_APPLICATION_ERROR
 * (codes -20001 à -20999, voir database/codes_erreurs.md).
 * Le message vient du package, déjà rédigé pour l'utilisateur.
 */
final class ErreurMetier extends \RuntimeException
{
    public const STOCK_INSUFFISANT = -20001;
    public const TRANSITION_INTERDITE = -20002;
    public const PANIER_VIDE = -20003;
    public const PRODUIT_INDISPONIBLE = -20004;
    public const QUANTITE_INVALIDE = -20005;
    public const CARTE_REFUSEE = -20006;
    public const CARTE_EXPIREE = -20007;
    public const EMAIL_DEJA_UTILISE = -20008;
    public const COMPTE_INTROUVABLE = -20009;
    public const AVIS_NON_AUTORISE = -20010;
    public const ETAT_ANNONCE_INVALIDE = -20011;
    public const NON_PROPRIETAIRE = -20012;
    public const CONVERSATION_INVALIDE = -20013;
    public const ROLE_INVALIDE = -20014;
    public const PROMOTION_INVALIDE = -20015;
    public const ANNULATION_IMPOSSIBLE = -20016;
    public const DONNEE_INVALIDE = -20017;
    public const INTROUVABLE = -20018;

    public function __construct(public readonly int $codeOracle, string $message)
    {
        parent::__construct($message, abs($codeOracle));
    }
}
