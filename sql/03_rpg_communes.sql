-- =========================================================
-- 03 - RPG : empilement des années, rattachement aux communes, classement des cultures
-- =========================================================

-- ---------------------------------------------------------
-- Étapes préalables dans QGIS (hors SQL)
-- ---------------------------------------------------------
-- 1. Extraction des RPG sur la Haute-Marne (extraire par localisation)
-- 2. Réparation des géométries (traitement par lot)
-- 3. Attribution du SCR EPSG:2154 (les couches étaient en IGNF:LAMB93)
-- 4. Export vers PostGIS (traitement par lot), tables rpg_2015 à rpg_2024


-- ---------------------------------------------------------
-- Correction des SCR
-- ---------------------------------------------------------
-- rpg_2024 n'avait pas de SRID : coordonnées déjà en Lambert 93, on corrige l'étiquette
SELECT UpdateGeometrySRID('rpg_2024', 'geom', 2154);

-- La couche communes était en WGS84 : on reprojette en Lambert 93
ALTER TABLE communes_repare
  ALTER COLUMN geom TYPE geometry(Geometry, 2154)
  USING ST_Transform(ST_SetSRID(geom, 4326), 2154);


-- ---------------------------------------------------------
-- Empilement des 10 années de RPG dans une seule table
-- ---------------------------------------------------------
CREATE TABLE rpg AS
SELECT 2015 AS annee, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2015
UNION ALL
SELECT 2016, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2016
UNION ALL
SELECT 2017, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2017
UNION ALL
SELECT 2018, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2018
UNION ALL
SELECT 2019, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2019
UNION ALL
SELECT 2020, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2020
UNION ALL
SELECT 2021, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2021
UNION ALL
SELECT 2022, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2022
UNION ALL
SELECT 2023, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2023
UNION ALL
SELECT 2024, code_cultu, geom, surf_adm::numeric, num_ilot::text, num_parcel::text FROM rpg_2024;


-- ---------------------------------------------------------
-- Rattachement de chaque parcelle à sa commune (jointure spatiale)
-- ---------------------------------------------------------
-- Chaque parcelle est rattachée à la commune qui contient son point intérieur
CREATE TABLE rpg_commune AS
SELECT r.*, dcoe_c_cod AS commune_code, dcoe_l_lib AS commune_nom
FROM rpg r
LEFT JOIN communes_repare c ON ST_Contains(c.geom, ST_PointOnSurface(r.geom));

-- Je recalcule les surfaces à partir des géométries (en hectares)
UPDATE rpg_commune
SET surf_adm = ROUND(ST_Area(geom)::numeric / 10000, 2);


-- ---------------------------------------------------------
-- Classement des cultures
-- ---------------------------------------------------------
-- Table de correspondance code culture -> catégorie
-- (remplie par import du fichier data/code_cult_cat_corrige.csv dans pgAdmin,
--  délimiteur ";", encodage WIN1252, en-tête : oui)
CREATE TABLE culture_correspondance_ (
    code_cultu text,
    categorie text
);

-- Niveau de risque de fuite d'azote par catégorie
ALTER TABLE culture_correspondance_
ADD COLUMN risque_fuite text;

UPDATE culture_correspondance_
SET risque_fuite =
    CASE
        WHEN categorie IN ('Colza', 'Maïs') THEN 'élevé'
        WHEN categorie IN ('Blé tendre d''hiver', 'Blé tendre de printemps', 'Blé dur', 'Orge', 'Autres céréales',
                           'Tournesol', 'Autres oléagineux', 'Protéagineux', 'Légumineuses à grains',
                           'Pommes de terre', 'Autres cultures industrielles', 'Autres cultures légumières',
                           'Fourrages annuels')
            THEN 'moyen'
        ELSE 'faible'
    END;

-- Ajout de la catégorie à chaque parcelle
ALTER TABLE rpg_commune
ADD COLUMN categorie_r text;

UPDATE rpg_commune r
SET categorie_r = c.categorie
FROM culture_correspondance_ c
WHERE r.code_cultu = c.code_cultu;
