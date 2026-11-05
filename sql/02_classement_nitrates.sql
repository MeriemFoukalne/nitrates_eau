-- =========================================================
-- 02 - Classement des analyses et indicateurs annuels par captage
-- =========================================================

-- ---------------------------------------------------------
-- Classement de chaque analyse
-- ---------------------------------------------------------
-- Conforme < 25 mg/L, sensible 25 à 50 mg/L, dépassement > 50 mg/L
-- Les analyses sans résultat sont exclues (sinon elles tombaient dans le ELSE = 'dépassement')
DROP TABLE IF EXISTS classement_nitrate;

CREATE TABLE classement_nitrate AS
SELECT identifiant_national_bss,
       com_nouvelle_nom AS commune_nom,
       com_nouvelle_code AS code_commune,
       date_prelevement,
       annee,
       resultat_de_lanalyse::numeric AS resultat_de_lanalyse,
       CASE
           WHEN resultat_de_lanalyse::numeric < 25 THEN 'conforme'
           WHEN resultat_de_lanalyse::numeric <= 50 THEN 'sensible'
           ELSE 'dépassement'
       END AS classement
FROM nitrate3
WHERE resultat_de_lanalyse IS NOT NULL;


-- ---------------------------------------------------------
-- Saisonnalité : mois et saison de prélèvement
-- ---------------------------------------------------------
-- Hiver = période de drainage (septembre à mars)
ALTER TABLE classement_nitrate
ADD COLUMN mois integer;

UPDATE classement_nitrate
SET mois = EXTRACT(MONTH FROM to_timestamp(date_prelevement, 'DD/MM/YYYY HH24:MI:SS'));

ALTER TABLE classement_nitrate
ADD COLUMN saison text;

UPDATE classement_nitrate
SET saison = CASE
    WHEN mois IN (9,10,11,12,1,2,3) THEN 'hiver'
    ELSE 'ete'
END;


-- ---------------------------------------------------------
-- Un captage de référence par commune
-- ---------------------------------------------------------
-- Diagnostic : certaines communes ont plusieurs captages (notamment les communes nouvelles)
SELECT com_nouvelle_code, com_nouvelle_nom,
       COUNT(DISTINCT identifiant_national_bss) AS nb_captages
FROM nitrate3
GROUP BY com_nouvelle_code, com_nouvelle_nom
HAVING COUNT(DISTINCT identifiant_national_bss) > 1
ORDER BY nb_captages DESC;

-- Je garde, pour chaque commune, le captage qui a le plus d'analyses
CREATE TABLE captage_reference AS
SELECT code_commune, commune_nom, identifiant_national_bss, nb_analyses
FROM (
    SELECT code_commune, commune_nom, identifiant_national_bss,
           COUNT(*) AS nb_analyses,
           ROW_NUMBER() OVER (PARTITION BY code_commune ORDER BY COUNT(*) DESC) AS rang
    FROM classement_nitrate
    GROUP BY code_commune, commune_nom, identifiant_national_bss
) t
WHERE rang = 1;


-- ---------------------------------------------------------
-- Indicateurs annuels par captage
-- ---------------------------------------------------------
DROP TABLE IF EXISTS nitrate_parametres;

CREATE TABLE nitrate_parametres AS
SELECT commune_nom, code_commune, identifiant_national_bss, annee,
       COUNT(*) FILTER (WHERE classement = 'dépassement') AS nb_depassement,
       COUNT(resultat_de_lanalyse) AS nb_prelevement,
       ROUND(AVG(resultat_de_lanalyse::numeric), 2) AS moyenne_nitrate,
       ROUND(COUNT(*) FILTER (WHERE classement = 'dépassement')::numeric
             / NULLIF(COUNT(resultat_de_lanalyse)::numeric, 0), 2) AS taux_dépassement,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY resultat_de_lanalyse::numeric)) AS mediane
FROM classement_nitrate
GROUP BY commune_nom, code_commune, identifiant_national_bss, annee;

-- Jointure pour ne garder que les captages de référence (un par commune)
CREATE TABLE nitrate_parametre AS (
    SELECT n.*, c.nb_analyses AS nb_analyses_total_chronique
    FROM nitrate_parametres n
    JOIN captage_reference c ON c.identifiant_national_bss = n.identifiant_national_bss
);

DROP TABLE IF EXISTS nitrate_parametres;
