-- =========================================================
-- 04 - Occupation du sol par commune et par année
-- =========================================================

-- ---------------------------------------------------------
-- Contrôle de complétude des RPG par année
-- ---------------------------------------------------------
-- -> 2019 à 2022 sont très incomplets (40 à 25 000 parcelles contre ~58 000 les autres années)
--    et sont exclus des analyses de tendance
SELECT annee, COUNT(*) AS nb_parcelles, ROUND(SUM(surf_adm)) AS surface_totale_ha
FROM rpg_commune
WHERE commune_code LIKE '52%'
GROUP BY annee
ORDER BY annee;


-- ---------------------------------------------------------
-- Surface et part de SAU par catégorie de culture
-- ---------------------------------------------------------
-- La SAU est calculée pour chaque commune ET chaque année (fonction de fenêtrage)
DROP TABLE IF EXISTS occupation_sol_commune;

CREATE TABLE occupation_sol_commune AS
SELECT annee, commune_code, commune_nom, categorie_r,
       SUM(surf_adm) AS sum,
       SUM(SUM(surf_adm)) OVER (PARTITION BY commune_code, annee) AS sau_tot,
       SUM(surf_adm) / SUM(SUM(surf_adm)) OVER (PARTITION BY commune_code, annee) AS proportion_culture
FROM rpg_commune
WHERE commune_code LIKE '52%'
GROUP BY annee, commune_code, commune_nom, categorie_r;

-- Ajout du niveau de risque de fuite à chaque catégorie
ALTER TABLE occupation_sol_commune
ADD COLUMN risque_fuite text;

UPDATE occupation_sol_commune o
SET risque_fuite = c.risque_fuite
FROM culture_correspondance_ c
WHERE o.categorie_r = c.categorie;

-- Contrôle : la somme des parts doit faire 1 pour chaque commune et chaque année
-- (aucune ligne attendue)
SELECT annee, commune_code, ROUND(SUM(proportion_culture)::numeric, 3) AS total
FROM occupation_sol_commune
GROUP BY annee, commune_code
HAVING ROUND(SUM(proportion_culture)::numeric, 3) <> 1;
