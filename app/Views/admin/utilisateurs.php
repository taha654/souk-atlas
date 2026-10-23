<?php
/** @var list<array<string, mixed>> $utilisateurs */
/** @var string $recherche */

use App\Core\Auth;
use App\Core\Csrf;
use App\Core\View;

$moi = Auth::utilisateur();
?>
<?= View::fragment('partials/menu_admin', ['actif' => '/admin/utilisateurs']) ?>
<h1>Utilisateurs</h1>
<form method="get" action="/admin/utilisateurs" class="form-quantite" role="search">
    <label for="q">Nom ou email</label>
    <input id="q" name="q" type="search" value="<?= e($recherche) ?>" maxlength="100">
    <button type="submit" class="bouton">Chercher</button>
</form>
<div class="defilement-horizontal">
    <table class="tableau-panier">
        <caption class="visuellement-cache">Utilisateurs (100 plus récents)</caption>
        <thead><tr><th scope="col">Nom</th><th scope="col">Email</th><th scope="col">Rôle</th><th scope="col">Statut</th>
            <th scope="col">Dernière connexion</th><th scope="col">Actions</th></tr></thead>
        <tbody>
        <?php foreach ($utilisateurs as $u): ?>
            <tr>
                <td><?= e($u['nom']) ?></td><td><?= e($u['email']) ?></td><td><?= e($u['role']) ?></td>
                <td><?= $u['statut'] === 'ACTIF' ? 'Actif' : '<span class="stock--epuise">Désactivé</span>' ?></td>
                <td><?= e(date_fr($u['derniere_connexion'], true)) ?></td>
                <td>
                    <?php if ($u['id'] !== $moi['id']): ?>
                        <form method="post" action="/admin/utilisateurs/<?= e($u['id']) ?>" class="form-quantite"><?= Csrf::champ() ?>
                            <label for="action-<?= e($u['id']) ?>" class="visuellement-cache">Action pour <?= e($u['nom']) ?></label>
                            <select id="action-<?= e($u['id']) ?>" name="action">
                                <?php foreach (['CLIENT', 'VENDEUR', 'ADMIN'] as $role): ?>
                                    <?php if ($role !== $u['role']): ?><option value="role:<?= $role ?>">Rôle : <?= strtolower($role) ?></option><?php endif; ?>
                                <?php endforeach; ?>
                                <option value="<?= $u['statut'] === 'ACTIF' ? 'desactiver' : 'reactiver' ?>"><?= $u['statut'] === 'ACTIF' ? 'Désactiver' : 'Réactiver' ?></option>
                            </select>
                            <button type="submit" class="bouton-lien">Appliquer</button>
                        </form>
                    <?php else: ?>
                        <span class="facultatif">(vous)</span>
                    <?php endif; ?>
                </td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
