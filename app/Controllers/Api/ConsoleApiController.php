<?php
declare(strict_types=1);

namespace App\Controllers\Api;

use App\Core\Controller;
use App\Core\Erreurs\ErreurMetier;
use App\Core\Response;
use App\Models\Boutique;
use App\Models\Categorie;
use App\Models\JetonApi;
use App\Models\Moderation;
use App\Models\ProduitVendeur;
use App\Models\RapportVentes;

/**
 * API JSON de l'outil console C++ (cpp/console), sous /api/console/.
 *
 * Authentification : en-tête "Authorization: Bearer souk_…" à CHAQUE requête
 * (pas de session, pas de cookie). C'est pourquoi le contrôleur frontal ne
 * demande pas de jeton CSRF ici (voir public/index.php).
 * Les règles de rôle sont les mêmes que sur le site : un vendeur importe dans
 * SA boutique et voit SES ventes ; seul l'admin modère et voit tout.
 */
final class ConsoleApiController extends Controller
{
    // Au-delà, la console découpe l'import en plusieurs requêtes
    public const PRODUITS_PAR_LOT = 100;

    /** GET /api/console/moi : vérifier son jeton */
    public function moi(): Response
    {
        $moi = $this->authentifier();
        if ($moi instanceof Response) {
            return $moi;
        }
        $boutique = $moi['role'] === 'VENDEUR' ? (new Boutique($this->db))->duVendeur($moi['id']) : null;
        return Response::json(['id' => $moi['id'], 'nom' => $moi['nom'], 'role' => $moi['role'],
            'boutique' => $boutique === null ? null : ['id' => $boutique['id'], 'nom' => $boutique['nom'], 'statut' => $boutique['statut']]]);
    }

    /** GET /api/console/categories : noms utilisables dans la colonne "categorie" du CSV */
    public function categories(): Response
    {
        $moi = $this->authentifier();
        if ($moi instanceof Response) {
            return $moi;
        }
        return Response::json(['categories' => array_map(
            static fn (array $c) => ['id' => $c['id'], 'nom' => $c['nom'], 'niveau' => $c['niveau']],
            (new Categorie($this->db))->arbre())]);
    }

    /**
     * POST /api/console/produits
     * Corps : {"produits": [{"ligne": 2, "nom": "…", "description": "…", "prix_ht": "129,90",
     *                       "stock": "10", "categorie": "Smartphones"}, …]}
     * Réponse : {"resultats": [{"ligne": 2, "ok": true, "id": 61} | {"ligne": 3, "ok": false, "erreur": "…"}]}
     *
     * Chaque produit est validé et enregistré SÉPARÉMENT (une transaction
     * chacun) : une ligne fausse n'empêche pas l'import des autres.
     */
    public function importerProduits(): Response
    {
        $moi = $this->authentifier('VENDEUR');
        if ($moi instanceof Response) {
            return $moi;
        }
        $boutique = (new Boutique($this->db))->duVendeur($moi['id']);
        if ($boutique === null) {
            return $this->erreur(409, 'Aucune boutique', 'Créez d\'abord votre boutique sur le site.');
        }
        $corps = $this->request->json();
        $produits = $corps['produits'] ?? null;
        if (!is_array($produits) || !array_is_list($produits) || $produits === []
            || count($produits) > self::PRODUITS_PAR_LOT) {
            return $this->erreur(400, 'Requête invalide',
                'Attendu : {"produits": [...]} avec 1 à ' . self::PRODUITS_PAR_LOT . ' produits.');
        }

        $categories = new Categorie($this->db);
        $modele = new ProduitVendeur($this->db);
        $resultats = [];
        foreach ($produits as $i => $p) {
            $ligne = is_array($p) && is_int($p['ligne'] ?? null) ? $p['ligne'] : $i + 1;
            $resultats[] = ['ligne' => $ligne] + $this->importerUn(is_array($p) ? $p : [], $boutique['id'], $categories, $modele);
        }
        return Response::json(['resultats' => $resultats]);
    }

    /** GET /api/console/signalements?statut=OUVERT (admin) */
    public function signalements(): Response
    {
        $moi = $this->authentifier('ADMIN');
        if ($moi instanceof Response) {
            return $moi;
        }
        $statut = $this->request->parametre('statut') ?: 'OUVERT';
        if (!in_array($statut, ['OUVERT', 'APPROUVE', 'REJETE'], true)) {
            return $this->erreur(400, 'Requête invalide', 'Statut attendu : OUVERT, APPROUVE ou REJETE.');
        }
        return Response::json(['signalements' => (new Moderation($this->db))->signalements($statut)]);
    }

    /** POST /api/console/signalements/{id}  corps : {"decision": "APPROUVER" | "REJETER"} (admin) */
    public function traiterSignalement(string $id): Response
    {
        $moi = $this->authentifier('ADMIN');
        if ($moi instanceof Response) {
            return $moi;
        }
        $idSignalement = filter_var($id, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        $decision = $this->request->json()['decision'] ?? null;
        if ($idSignalement === false || !in_array($decision, ['APPROUVER', 'REJETER'], true)) {
            return $this->erreur(400, 'Requête invalide', 'Attendu : un identifiant et {"decision": "APPROUVER" | "REJETER"}.');
        }
        try {
            (new Moderation($this->db))->traiterSignalement($idSignalement, $moi['id'], $decision);
            $this->db->valider();
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            return $this->erreur(422, 'Action impossible', $erreur->getMessage());
        }
        return Response::json(['id' => $idSignalement, 'decision' => $decision, 'ok' => true]);
    }

    /** GET /api/console/rapport?debut=2026-01-01&fin=2026-03-31 : ventes du vendeur, ou de tout le site (admin) */
    public function rapport(): Response
    {
        $moi = $this->authentifier('VENDEUR', 'ADMIN');
        if ($moi instanceof Response) {
            return $moi;
        }
        $debut = $this->request->parametre('debut');
        $fin = $this->request->parametre('fin');
        $erreur = RapportVentes::erreurPeriode($debut, $fin);
        if ($erreur !== null) {
            return $this->erreur(400, 'Requête invalide', $erreur);
        }
        $idBoutique = null;
        if ($moi['role'] === 'VENDEUR') {
            $boutique = (new Boutique($this->db))->duVendeur($moi['id']);
            if ($boutique === null) {
                return $this->erreur(409, 'Aucune boutique', 'Créez d\'abord votre boutique sur le site.');
            }
            $idBoutique = $boutique['id'];
        }
        return Response::json((new RapportVentes($this->db))->generer($debut, $fin, $idBoutique));
    }

    // ------------------------------------------------------------------ outils

    /**
     * Utilisateur du jeton, avec l'un des rôles demandés ; sinon une réponse
     * d'erreur JSON (401 sans jeton valide, 403 avec le mauvais rôle).
     *
     * @return array{id: int, nom: string, role: string}|Response
     */
    private function authentifier(string ...$roles): array|Response
    {
        $entete = $this->request->entete('Authorization') ?? '';
        $jeton = preg_match('/^Bearer\s+(\S+)$/', $entete, $m) === 1 ? $m[1] : '';
        $moi = $jeton === '' ? null : (new JetonApi($this->db))->utilisateur($jeton);
        if ($moi === null) {
            return $this->erreur(401, 'Non authentifié', 'Jeton d\'API absent, invalide, expiré ou révoqué.')
                ->avecEntete('WWW-Authenticate', 'Bearer');
        }
        // La date de dernière utilisation du jeton est enregistrée ; les triggers
        // d'audit sauront aussi QUI agit (comme pour une session du site)
        $this->db->valider();
        $this->db->definirUtilisateur($moi['id']);
        if ($roles !== [] && !in_array($moi['role'], $roles, true)) {
            return $this->erreur(403, 'Accès refusé', 'Rôle ' . $moi['role'] . ' insuffisant pour cette commande.');
        }
        return $moi;
    }

    /**
     * @param array<string, mixed> $p
     * @return array{ok: bool, id?: int, erreur?: string}
     */
    private function importerUn(array $p, int $idBoutique, Categorie $categories, ProduitVendeur $modele): array
    {
        $texte = static fn (string $cle): string => is_scalar($p[$cle] ?? null) ? trim((string) $p[$cle]) : '';
        $nomCategorie = $texte('categorie');
        $idCategorie = ctype_digit($nomCategorie) ? $categories->existe((int) $nomCategorie) : $categories->parNom($nomCategorie);
        if ($idCategorie === null) {
            return ['ok' => false, 'erreur' => 'catégorie inconnue « ' . mb_substr($nomCategorie, 0, 60) . ' »'];
        }
        // Mêmes règles que le formulaire du site (une seule source de vérité)
        [$valeurs, $erreurs] = ProduitVendeur::validerFormulaire([
            'nom' => $texte('nom'), 'description' => $texte('description'), 'prix_ht' => $texte('prix_ht'),
            'id_categorie' => (string) $idCategorie, 'stock' => $texte('stock'),
        ], true);
        if ($erreurs !== []) {
            return ['ok' => false, 'erreur' => implode(' ', $erreurs)];
        }
        try {
            $id = $modele->creer($idBoutique, $valeurs);
            $this->db->valider();
            return ['ok' => true, 'id' => $id];
        } catch (ErreurMetier $erreur) {
            $this->db->annuler();
            return ['ok' => false, 'erreur' => $erreur->getMessage()];
        }
    }

    private function erreur(int $statut, string $titre, string $message): Response
    {
        return Response::json(['erreur' => $titre, 'message' => $message], $statut);
    }
}
