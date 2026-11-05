-- =========================================================
-- 01 - Import et nettoyage des analyses de nitrates (ADES)
-- =========================================================

-- ---------------------------------------------------------
-- Étape manuelle préalable (hors SQL)
-- ---------------------------------------------------------
-- 1. Lecture de la ligne d'en-tête du fichier ADES dans PowerShell,
--    sans ouvrir le fichier (trop volumineux) :
--      Get-Content "chemin\vers\analyses.txt" -TotalCount 2
--    -> séparateur "|", 63 colonnes + un "|" final (64 champs).
-- 2. Création de la table de staging "points2" (ci-dessous, toutes colonnes en texte).
-- 3. Import du fichier dans pgAdmin (Import/Export Data) :
--    format csv, délimiteur "|", en-tête : oui, encodage : LATIN1.

-- ---------------------------------------------------------
-- Table de staging (64 colonnes, dont une colonne "vide" due au "|" en fin de ligne)
-- ---------------------------------------------------------
CREATE TABLE points2 (
    Identifiant_national_BSS text,
    Ancien_code_national_BSS text,
    Code_type_qualitometre text,
    Type_qualitometre text,
    Date_prelevement text,
    Numero_de_prelevement text,
    Date_de_lanalyse text,
    Finalites_des_prelevements text,
    Numero_analyse text,
    Code_parametre text,
    Parametre text,
    Code_remarque_analyse text,
    Remarque_analyse text,
    Resultat_de_lanalyse text,
    Code_unite text,
    Unite text,
    Code_methode_analyse text,
    Methode_analyse text,
    Reference_laboratoire text,
    Code_laboratoire text,
    Laboratoire text,
    Code_fraction_analysee text,
    Fraction_analysee text,
    Code_support text,
    Support text,
    Code_lieu_analyse text,
    Lieu_analyse text,
    Code_qualification text,
    Qualification text,
    Code_statut_mesure text,
    Statut_mesure text,
    Code_producteur_echantillon text,
    Producteur_echantillon text,
    Code_producteur_donnees text,
    Producteur_donnees text,
    Reference_de_lanalyse_chez_le_producteur text,
    Resultat_de_reference text,
    Code_difficulte text,
    Difficulte text,
    Commentaires_analyse text,
    Commentaires_resultats text,
    Code_commune_dossier_BSS text,
    Commune_dossier_BSS text,
    X_WGS84 text,
    Y_WGS84 text,
    Profondeur_debut_site_de_mesure text,
    Profondeur_fin_site_de_mesure text,
    Reference_echantillon text,
    Code_methode_fraction text,
    Methode_fraction text,
    Limite_quantification text,
    Limite_detection text,
    Seuil_saturation text,
    Accreditation_resultat text,
    Incertitude_analytique text,
    Code_parametre_solvant text,
    Parametre_solvant text,
    Code_methode_extraction text,
    Methode_extraction text,
    Rendement_extraction text,
    Volume_filtre text,
    Code_responsable_validation text,
    Responsable_validation text,
    vide text
);


-- ---------------------------------------------------------
-- Extraction des nitrates (code SANDRE 1340)
-- ---------------------------------------------------------
CREATE TABLE nitrate2 AS
SELECT *
FROM points2
WHERE code_parametre = '1340';

-- Je ne garde que les champs utiles
CREATE TABLE nitrate3 AS
SELECT identifiant_national_bss,
       code_commune_dossier_bss,
       commune_dossier_bss,
       resultat_de_lanalyse,
       ancien_code_national_bss,
       date_prelevement,
       parametre,
       remarque_analyse
FROM nitrate2;


-- ---------------------------------------------------------
-- Couche des communes de Haute-Marne
-- ---------------------------------------------------------
CREATE TABLE commune_HM AS
SELECT *
FROM communes_repare
WHERE ddep_c_cod = '52';


-- ---------------------------------------------------------
-- Harmonisation des codes communes
-- ---------------------------------------------------------
-- Contrôle : je vérifie que toutes les communes des analyses existent dans la couche communes
WITH liste_commune_nitrate AS (
    SELECT DISTINCT code_commune_dossier_bss, commune_dossier_bss
    FROM nitrate3
),
liste_commune_commune AS (
    SELECT DISTINCT dcoe_c_cod, dcoe_l_lib
    FROM commune_hm
)
SELECT n.code_commune_dossier_bss, n.commune_dossier_bss, c.dcoe_c_cod, c.dcoe_l_lib
FROM liste_commune_nitrate n
LEFT JOIN liste_commune_commune c ON n.code_commune_dossier_bss = c.dcoe_c_cod
WHERE dcoe_c_cod IS NULL OR dcoe_l_lib IS NULL;
-- -> certaines communes ne correspondent pas : ce sont des communes associées / déléguées

-- Je crée les nouveaux champs, je copie les valeurs d'origine,
-- puis je remplace les communes déléguées par leur commune nouvelle
ALTER TABLE nitrate3
ADD com_nouvelle_code text,
ADD com_nouvelle_nom text;

UPDATE nitrate3
SET com_nouvelle_code = code_commune_dossier_bss,
    com_nouvelle_nom  = commune_dossier_bss;

-- J'utilise une table intermédiaire (VALUES) dans ma requête pour modifier les champs,
-- avec une condition qui permet de ne changer que les bonnes lignes
UPDATE nitrate3 n
SET com_nouvelle_code = c.code_n,   -- à gauche : le champ à modifier dans la table, sans alias
    com_nouvelle_nom  = c.nom_n
FROM (VALUES
    ('52351','52064','Bourmont-entre-Meuse-et-Mouzon'),
    ('52225','52064','Bourmont-entre-Meuse-et-Mouzon'),
    ('52532','52497','Troisfontaines-la-Ville'),
    ('52262','52140','Colombey les Deux Églises'),
    ('52296','52411','Rives Dervoises'),
    ('52293','52411','Rives Dervoises'),
    ('52202','52497','Troisfontaines-la-Ville'),
    ('52020','52273','Larivière-Arnoncourt'),
    ('52427','52331','La Porte du Der'),
    ('52509','52405','Le Montsaugeonnais'),
    ('52036','52449','Saints-Geosmes')
) AS c(code_ancien, code_n, nom_n)
WHERE n.code_commune_dossier_bss = c.code_ancien;

-- Contrôle : je revérifie que je n'ai plus de valeur nulle dans ma liste de communes
WITH liste_commune_nitrate AS (
    SELECT DISTINCT com_nouvelle_code, com_nouvelle_nom
    FROM nitrate3
),
liste_commune_commune AS (
    SELECT DISTINCT dcoe_c_cod, dcoe_l_lib
    FROM commune_hm
)
SELECT n.com_nouvelle_code, n.com_nouvelle_nom, c.dcoe_c_cod, c.dcoe_l_lib
FROM liste_commune_nitrate n
LEFT JOIN liste_commune_commune c ON n.com_nouvelle_code = c.dcoe_c_cod
WHERE dcoe_c_cod IS NULL OR dcoe_l_lib IS NULL;
-- -> plus de valeurs nulles


-- ---------------------------------------------------------
-- Ajout de l'année de prélèvement
-- ---------------------------------------------------------
ALTER TABLE nitrate3
ADD COLUMN annee integer;

UPDATE nitrate3
SET annee = EXTRACT(YEAR FROM to_timestamp(date_prelevement, 'DD/MM/YYYY HH24:MI:SS'));
