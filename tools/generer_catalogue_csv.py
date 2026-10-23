#!/usr/bin/env python3
"""
Génère cpp/console/exemples/catalogue_100.csv : 100 produits FICTIFS pour
tester « souk-console import-csv », dont 8 lignes volontairement fausses
(6 refusées par la console elle-même, 3 par le serveur) : 91 doivent être importés.
Le fichier produit est versionné ; ce script sert à le régénérer à l'identique.
    python3 tools/generer_catalogue_csv.py
"""
import csv
import io
import random
from pathlib import Path

random.seed(2026)   # graine fixe : même fichier à chaque exécution

FAMILLES = {
    'Accessoires téléphone': (['Câble USB-C tressé', 'Chargeur rapide 25 W', 'Support voiture magnétique',
                               'Batterie externe 10 000 mAh', 'Écouteurs filaires'], (49, 299)),
    'Périphériques': (['Souris sans fil', 'Clavier AZERTY rétroéclairé', 'Webcam Full HD', 'Hub USB 4 ports',
                       'Tapis de souris XXL'], (59, 499)),
    'Électroménager': (['Bouilloire inox 1,7 L', 'Grille-pain 2 fentes', 'Mixeur plongeant', 'Fer à repasser vapeur',
                        'Ventilateur sur pied'], (149, 899)),
    'Cuisine & art de la table': (['Tajine en terre cuite', 'Théière en inox', 'Service à thé 6 verres',
                                   'Plat à couscous', 'Couscoussier 6 L'], (79, 649)),
    'Tapis & artisanat': (['Tapis berbère tissé main', 'Pouf en cuir', 'Lanterne en laiton', 'Coussin brodé',
                           'Plateau en cuivre martelé'], (199, 2499)),
    'Tenues traditionnelles': (['Djellaba en laine', 'Caftan brodé', 'Babouches en cuir', 'Gandoura en lin',
                                'Jabador homme'], (149, 1899)),
    'Soins & cosmétiques': (["Huile d'argan pure 100 ml", 'Savon noir à l’eucalyptus', 'Ghassoul naturel',
                             'Eau de rose 200 ml', 'Crème au karité'], (29, 249)),
    'Fitness': (['Tapis de yoga', 'Haltères 2 × 5 kg', 'Corde à sauter', 'Bandes élastiques', 'Gourde isotherme'],
                (39, 599)),
    'Jouets': (['Puzzle 500 pièces', 'Jeu de construction', 'Voiture télécommandée', 'Peluche dromadaire',
                'Jeu de société en famille'], (49, 449)),
}
COULEURS = ['bleu', 'noir', 'beige', 'rouge', 'vert', 'naturel', 'gris', 'sable']


def prix_francais(valeur):
    """1299.9 → "1 299,90" : le format que produit Excel réglé en français"""
    entier, decimales = f'{valeur:.2f}'.split('.')
    groupes = []
    while len(entier) > 3:
        groupes.insert(0, entier[-3:])
        entier = entier[:-3]
    groupes.insert(0, entier)
    return ' '.join(groupes) + ',' + decimales


lignes = []
for categorie, (noms, (bas, haut)) in FAMILLES.items():
    for nom in noms:
        for couleur in random.sample(COULEURS, 3):   # 3 coloris différents : pas de doublon
            prix = round(random.uniform(bas, haut), random.choice([0, 2]))
            description = f'{nom}, coloris {couleur}. Produit de démonstration (fictif).'
            if random.random() < 0.15:
                # Pour vérifier la lecture des champs entre guillemets
                description += ' Finition « premium » ; garantie 1 an, dit "solide".'
            lignes.append([f'{nom} — {couleur}', description, prix_francais(prix),
                           str(random.randint(0, 80)), categorie])
random.shuffle(lignes)
lignes = lignes[:91]

# Lignes volontairement fausses, avec le motif attendu en commentaire
fausses = [
    ['Lampe de chevet', 'Prix écrit en toutes lettres', 'douze', '4', 'Décoration & meubles'],       # prix illisible
    ['Vase en céramique', 'Trois décimales', '12,999', '4', 'Décoration & meubles'],                 # prix
    ['Tabouret en bois', 'Stock négatif', '150', '-3', 'Décoration & meubles'],                     # stock
    ['TV', 'Nom trop court', '2500', '2', 'TV, audio & consoles'],                                   # nom
    ['Miroir mural', 'Pas de catégorie', '320', '6', ''],                                           # catégorie vide
    ['Hoverboard 6,5 pouces', 'Catégorie inexistante', '1 490,00', '5', 'Hoverboards'],              # serveur
    ['Drone caméra 4K', 'Catégorie inexistante', '2 990,00', '3', 'Drones'],                         # serveur
    ['Tablette éducative', 'Identifiant de catégorie inconnu', '890', '7', '999'],                   # serveur
]

def en_csv(ligne):
    tampon = io.StringIO()
    csv.writer(tampon, delimiter=';', lineterminator='\r\n').writerow(ligne)
    return tampon.getvalue()


textes = [en_csv(ligne) for ligne in lignes]
for position, ligne in zip([7, 19, 33, 46, 58, 71, 84, 97], fausses):
    textes.insert(position - 1, en_csv(ligne))
# Colonne manquante (pas de stock) : ligne écrite à la main, csv.writer ne le ferait pas
textes.insert(89, 'Bougie parfumée;Ambre et oud;89,00;Décoration & meubles\r\n')

chemin = Path(__file__).resolve().parent.parent / 'cpp/console/exemples/catalogue_100.csv'
with chemin.open('w', newline='', encoding='utf-8') as fichier:
    fichier.write(en_csv(['nom', 'description', 'prix_ht', 'stock', 'categorie']))
    fichier.writelines(textes)
print(f'{len(textes)} lignes de produits écrites dans {chemin}')
