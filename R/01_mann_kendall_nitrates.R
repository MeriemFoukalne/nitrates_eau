# =========================================================
# 01 - Tendance des nitrates par captage
# Test de Mann-Kendall + pente de Sen sur les médianes annuelles
# =========================================================

library(dplyr)
library(trend)
library(DBI)

# La connexion "con" à la base Postgres a été créée dans l'onglet Connections de RStudio
# (pilote PostgreSQL ODBC)

# ---- 1. Import de la table des médianes annuelles ----
mediane <- dbReadTable(con, "nitrate_parametre")

# ---- 2. Fonction : pente de Sen sur les vraies années ----
# (calcule la pente de chaque paire d'années, puis prend la médiane)
pente_sen <- function(valeur, annee) {
  paires <- combn(length(valeur), 2)
  median((valeur[paires[2, ]] - valeur[paires[1, ]]) /
           (annee[paires[2, ]]  - annee[paires[1, ]]))
}

# ---- 3. Test de Mann-Kendall par captage sur la médiane ----
resultats_mk <- mediane %>%
  mutate(
    annee            = as.integer(annee),
    mediane_annuelle = as.numeric(mediane)
  ) %>%
  filter(!is.na(mediane)) %>%
  arrange(identifiant_national_bss, code_commune, commune_nom, annee, nb_analyses_total_chronique) %>%
  group_by(identifiant_national_bss, code_commune, commune_nom, nb_analyses_total_chronique) %>%
  filter(n() >= 8) %>%
  summarise(
    n_annees    = n(),
    annee_debut = min(annee),
    annee_fin   = max(annee),
    p_value     = mk.test(mediane_annuelle)$p.value,
    pente_sen   = pente_sen(mediane_annuelle, annee),
    .groups     = "drop"
  ) %>%
  mutate(tendance = case_when(
    p_value < 0.05 & pente_sen > 0 ~ "hausse",
    p_value < 0.05 & pente_sen < 0 ~ "baisse",
    TRUE                           ~ "pas de tendance significative"
  ))

# ---- 4. Vérification rapide ----
print(resultats_mk)
table(resultats_mk$tendance)

# ---- 5. Renvoi des résultats dans Postgres ----
dbWriteTable(con, "tendance_mediane", resultats_mk, overwrite = TRUE)
