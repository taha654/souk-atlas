// =============================================================================
// Chargement du module WebAssembly (compilé depuis cpp/ par Emscripten) et
// solutions de REPLI en JavaScript pur, avec exactement la même interface.
//
//   const moteur = await obtenirMoteur();
//   moteur.nom                          → "WebAssembly" ou "JavaScript"
//   moteur.creerIndex()                 → index de recherche tolérante
//   moteur.dimensionsReduites(l, h, c)  → {largeur, hauteur}
//   moteur.reduireRgba(pixels, l, h, nl, nh) → Uint8ClampedArray
//
// Le repli sert si le navigateur ne connaît pas WebAssembly, si le fichier
// .wasm ne se charge pas (réseau, CSP…), ou si on le demande (?moteur=js),
// pour comparer les deux versions.
// =============================================================================

let promesse = null;

/** Le moteur, chargé une seule fois pour toute la page */
export function obtenirMoteur() {
    promesse ??= charger();
    return promesse;
}

async function charger() {
    if (new URLSearchParams(location.search).get('moteur') !== 'js' && typeof WebAssembly === 'object') {
        try {
            // import() dynamique : le module n'est téléchargé que si une page en a besoin
            const { default: creerModuleSouk } = await import('/assets/wasm/souk.js');
            return moteurWasm(await creerModuleSouk());
        } catch (erreur) {
            console.warn('WebAssembly indisponible, repli JavaScript :', erreur);
        }
    }
    return moteurJavaScript();
}

// ----------------------------------------------------------------- WebAssembly

function moteurWasm(module) {
    return {
        nom: 'WebAssembly',
        creerIndex: () => new module.RechercheTolerante(),
        dimensionsReduites: (l, h, cote) => module.dimensionsReduites(l, h, cote),
        reduireRgba(pixels, largeur, hauteur, nouvelleLargeur, nouvelleHauteur) {
            const tailleSource = largeur * hauteur * 4;
            const tailleCible = nouvelleLargeur * nouvelleHauteur * 4;
            // Réservation de deux zones dans la mémoire du module (comme malloc en C)
            const source = module._malloc(tailleSource);
            const cible = module._malloc(tailleCible);
            try {
                if (source === 0 || cible === 0) throw new Error('mémoire WebAssembly insuffisante');
                // HEAPU8 relu APRÈS _malloc : si la mémoire a dû grandir, l'ancienne vue est périmée
                module.HEAPU8.set(pixels, source);
                if (!module.reduireRgba(source, largeur, hauteur, cible, nouvelleLargeur, nouvelleHauteur)) {
                    throw new Error('dimensions refusées par le module');
                }
                // slice() COPIE le résultat : la zone sera libérée juste après
                return new Uint8ClampedArray(module.HEAPU8.slice(cible, cible + tailleCible).buffer);
            } finally {
                // Pas de ramasse-miettes dans la mémoire WebAssembly : on libère à la main
                module._free(source);
                module._free(cible);
            }
        },
    };
}

// ----------------------------------------------------------------- repli JavaScript

/** Mêmes règles que cpp/common/Texte.cpp : minuscules, sans accents, mots alphanumériques */
function mots(texte) {
    return texte.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
        .split(/[^a-z0-9]+/).filter(Boolean);
}

/** Distance d'édition avec transpositions (cpp/common/Levenshtein.cpp), sur deux lignes + une */
function distance(a, b) {
    const x = [...a];
    const y = [...b];
    let avantDerniere = [];
    let precedente = Array.from({ length: y.length + 1 }, (_, j) => j);
    for (let i = 1; i <= x.length; i++) {
        const courante = [i];
        for (let j = 1; j <= y.length; j++) {
            const cout = x[i - 1] === y[j - 1] ? 0 : 1;
            courante[j] = Math.min(precedente[j] + 1, courante[j - 1] + 1, precedente[j - 1] + cout);
            if (i > 1 && j > 1 && x[i - 1] === y[j - 2] && x[i - 2] === y[j - 1]) {
                courante[j] = Math.min(courante[j], avantDerniere[j - 2] + 1);
            }
        }
        avantDerniere = precedente;
        precedente = courante;
    }
    return precedente[y.length];
}

const tolerance = (longueur) => (longueur <= 3 ? 0 : longueur <= 5 ? 1 : longueur <= 9 ? 2 : 3);

class IndexJavaScript {
    #entrees = [];
    ajouter(id, titre) { this.#entrees.push({ id, titre, mots: mots(titre) }); }
    vider() { this.#entrees = []; }
    taille() { return this.#entrees.length; }
    rechercher(requete, limite) {
        const cherches = mots(requete);
        if (cherches.length === 0) return [];
        const resultats = [];
        for (const entree of this.#entrees) {
            let total = 0;
            const tousTrouves = cherches.every((cherche, k) => {
                const enCoursDeFrappe = k === cherches.length - 1 && cherche.length >= 3;
                let meilleure = Infinity;
                for (const mot of entree.mots) {
                    meilleure = Math.min(meilleure, distance(cherche, mot));
                    if (enCoursDeFrappe && mot.length > cherche.length) {
                        meilleure = Math.min(meilleure, distance(cherche, mot.slice(0, cherche.length)));
                    }
                }
                total += meilleure;
                return meilleure <= tolerance(cherche.length);
            });
            if (tousTrouves) resultats.push({ id: entree.id, nom: entree.titre, distance: total });
        }
        // sort est stable : à égalité, l'ordre d'ajout est conservé (comme std::stable_sort)
        resultats.sort((a, b) => a.distance - b.distance || a.nom.length - b.nom.length);
        return resultats.slice(0, limite);
    }
}

function dimensionsReduites(largeur, hauteur, cote) {
    if (largeur <= cote && hauteur <= cote) return { largeur, hauteur };
    const facteur = cote / Math.max(largeur, hauteur);
    return { largeur: Math.max(1, Math.round(largeur * facteur)), hauteur: Math.max(1, Math.round(hauteur * facteur)) };
}

/** Moyenne de zone séparable, comme cpp/common/Redimensionnement.cpp */
function contributions(depart, arrivee) {
    const echelle = depart / arrivee;
    return Array.from({ length: arrivee }, (_, i) => {
        const debut = i * echelle;
        const fin = (i + 1) * echelle;
        const premier = Math.floor(debut);
        const dernier = Math.min(depart - 1, Math.ceil(fin) - 1);
        const poids = [];
        for (let s = premier; s <= dernier; s++) poids.push((Math.min(fin, s + 1) - Math.max(debut, s)) / echelle);
        return { premier, poids };
    });
}

function reduireRgba(pixels, largeur, hauteur, nouvelleLargeur, nouvelleHauteur) {
    const horizontales = contributions(largeur, nouvelleLargeur);
    const verticales = contributions(hauteur, nouvelleHauteur);
    const sortie = new Uint8ClampedArray(nouvelleLargeur * nouvelleHauteur * 4);
    const ligneReduite = new Float32Array(nouvelleLargeur * 4);
    const accumulateur = new Float32Array(nouvelleLargeur * 4);
    for (let y = 0; y < nouvelleHauteur; y++) {
        accumulateur.fill(0);
        const cv = verticales[y];
        cv.poids.forEach((py, k) => {
            const debutLigne = (cv.premier + k) * largeur * 4;
            for (let x = 0; x < nouvelleLargeur; x++) {
                const ch = horizontales[x];
                let r = 0, v = 0, b = 0, a = 0;
                ch.poids.forEach((px, m) => {
                    const p = debutLigne + (ch.premier + m) * 4;
                    r += pixels[p] * px; v += pixels[p + 1] * px; b += pixels[p + 2] * px; a += pixels[p + 3] * px;
                });
                ligneReduite.set([r, v, b, a], x * 4);
            }
            for (let i = 0; i < accumulateur.length; i++) accumulateur[i] += ligneReduite[i] * py;
        });
        // Uint8ClampedArray arrondit et borne entre 0 et 255 tout seul
        sortie.set(accumulateur, y * nouvelleLargeur * 4);
    }
    return sortie;
}

function moteurJavaScript() {
    return { nom: 'JavaScript', creerIndex: () => new IndexJavaScript(), dimensionsReduites, reduireRgba };
}
