<?php
declare(strict_types=1);

namespace App\Controllers;

use App\Core\Auth;
use App\Core\Config;
use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Response;
use App\Core\Session;
use App\Models\Utilisateur;
use App\Services\Panier;

final class AuthController extends Controller
{
    // Hash bcrypt d'une chaîne aléatoire inconnue. Quand l'email n'existe pas, on
    // vérifie quand même le mot de passe contre ce hash : la réponse prend le même
    // temps, et ne révèle donc pas si l'email est inscrit.
    private const HASH_FACTICE = '$2y$10$TKOthXb4AyY9V6jr88Na9ewH0g83hzJ2a1cZs6HTrFnxviaollmQS';
    private const MESSAGE_ECHEC = 'Email ou mot de passe incorrect.';

    // ------------------------------------------------------------------ inscription

    public function formulaireInscription(): Response
    {
        if (Auth::estConnecte()) {
            return $this->rediriger(Auth::accueilDuRole(Auth::utilisateur()['role']));
        }
        return $this->vue('auth/inscription', ['valeurs' => ['role' => 'CLIENT'], 'erreurs' => []], 'Inscription');
    }

    public function inscrire(): Response
    {
        if (Auth::estConnecte()) {
            return $this->rediriger(Auth::accueilDuRole(Auth::utilisateur()['role']));
        }

        $valeurs = [
            'nom' => $this->request->champ('nom'),
            'email' => mb_strtolower($this->request->champ('email')),
            'telephone' => $this->request->champ('telephone'),
            'ville' => $this->request->champ('ville'),
            'role' => $this->request->champ('role'),
        ];
        $motDePasse = $this->request->champBrut('mot_de_passe');
        $erreurs = Utilisateur::validerInscription($valeurs + [
            'mot_de_passe' => $motDePasse,
            'confirmation' => $this->request->champBrut('confirmation'),
        ]);

        if ($erreurs === []) {
            try {
                $id = (new Utilisateur($this->db))->creer($valeurs, $motDePasse);
                $refus = (new Panier($this->db, $id))->fusionnerDepuisSession();
                $this->db->valider();
                Auth::connecter($id);
                self::signalerRefus($refus);
                Session::flash('succes', 'Bienvenue sur Souk Atlas, ' . $valeurs['nom'] . ' !');
                return $this->rediriger(Auth::accueilDuRole($valeurs['role']));
            } catch (ErreurMetier $erreur) {
                $this->db->annuler();
                // Le package a détecté l'email en double grâce à l'index unique
                $champ = $erreur->codeOracle === ErreurMetier::EMAIL_DEJA_UTILISE ? 'email' : 'general';
                $erreurs[$champ] = $erreur->getMessage();
            }
        }

        // 422 : la requête est bien formée, mais son contenu est invalide.
        // Le mot de passe n'est jamais renvoyé dans le formulaire.
        return $this->vue('auth/inscription', ['valeurs' => $valeurs, 'erreurs' => $erreurs], 'Inscription', 422);
    }

    // ------------------------------------------------------------------ connexion

    public function formulaireConnexion(): Response
    {
        if (Auth::estConnecte()) {
            return $this->rediriger(Auth::accueilDuRole(Auth::utilisateur()['role']));
        }
        return $this->vue('auth/connexion', [
            'email' => '',
            'retour' => Auth::retourSur($this->request->parametre('retour')) ?? '',
            'erreur' => null,
        ], 'Connexion');
    }

    public function connecter(): Response
    {
        $limites = Config::get('connexion');
        $email = mb_strtolower($this->request->champ('email'));
        $motDePasse = $this->request->champBrut('mot_de_passe');
        $retour = Auth::retourSur($this->request->champ('retour')) ?? '';
        $ip = $this->request->ip;
        $modele = new Utilisateur($this->db);

        $echec = fn (string $message, int $statut) => $this->vue('auth/connexion',
            ['email' => $email, 'retour' => $retour, 'erreur' => $message], 'Connexion', $statut);

        // 1. Blocage AVANT toute vérification du mot de passe : pendant un blocage,
        //    même le bon mot de passe est refusé (sinon l'attaquant saurait qu'il l'a trouvé)
        if ($modele->nbEchecsEmail($email, $limites['fenetre_minutes']) >= $limites['max_echecs_email']
            || $modele->nbEchecsIp($ip, $limites['fenetre_minutes']) >= $limites['max_echecs_ip']) {
            // 429 Too Many Requests
            return $echec('Trop de tentatives de connexion. Réessayez dans '
                . $limites['fenetre_minutes'] . ' minutes.', 429);
        }

        // 2. Vérification du mot de passe, en temps constant que le compte existe ou non
        $compte = $email === '' ? null : $modele->trouverParEmail($email);
        $motDePasseCorrect = password_verify($motDePasse, $compte['MOT_DE_PASSE_HASH'] ?? self::HASH_FACTICE);

        if ($compte === null || !$motDePasseCorrect) {
            $modele->enregistrerTentative($email, $ip, false);
            $this->db->valider();
            // Même message que l'email existe ou non : on ne révèle pas qui est inscrit
            return $echec(self::MESSAGE_ECHEC, 401);
        }

        // Le mot de passe est correct : on peut dire que le compte est désactivé
        // (l'information ne sert à rien à qui ne connaît pas le mot de passe)
        if ($compte['STATUT'] !== 'ACTIF') {
            $modele->enregistrerTentative($email, $ip, false);
            $this->db->valider();
            return $echec('Ce compte a été désactivé. Contactez l\'administrateur.', 403);
        }

        // 3. Succès
        $id = (int) $compte['ID'];
        // Si l'algorithme ou le coût par défaut de PHP a changé depuis la création
        // du hash, on en profite pour le recalculer (on a le mot de passe en clair ici)
        if (password_needs_rehash($compte['MOT_DE_PASSE_HASH'], PASSWORD_DEFAULT)) {
            $modele->changerHash($id, $motDePasse);
        }
        $modele->enregistrerTentative($email, $ip, true);
        $modele->enregistrerConnexion($id);
        // Le panier rempli avant la connexion rejoint le panier du compte
        $refus = (new Panier($this->db, $id))->fusionnerDepuisSession();
        $this->db->valider();

        Auth::connecter($id);
        self::signalerRefus($refus);
        Session::flash('succes', 'Bonjour ' . $compte['NOM'] . ' !');
        return $this->rediriger($retour !== '' ? $retour : Auth::accueilDuRole($compte['ROLE']));
    }

    /** @param list<string> $refus produits du panier de session non repris (stock…) */
    private static function signalerRefus(array $refus): void
    {
        foreach ($refus as $message) {
            Session::flash('erreur', 'Panier : ' . $message);
        }
    }

    // ------------------------------------------------------------------ déconnexion

    public function deconnecter(): Response
    {
        // POST uniquement, avec jeton CSRF (vérifié par le contrôleur frontal) :
        // une image <img src="/deconnexion"> sur un autre site ne peut rien faire
        Auth::deconnecter();
        Session::flash('info', 'Vous êtes déconnecté.');
        return $this->rediriger('/');
    }
}
