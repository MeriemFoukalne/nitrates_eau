# =========================================================
# 02 - Tendance de l'occupation du sol par niveau de risque, par commune
# Test de Mann-Kendall + pente de Sen sur la part de SAU
# Années 2019 à 2022 exclues (RPG incomplet)
# =========================================================

library(dplyr)
library(tidyr)
library(trend)
library(DBI)

# ---- 1. Import ----
occupation <- dbReadTable(con, "occupation_sol_commune")

# ---- 2. Part de SAU par commune, année et niveau de risque ----
risque_annuel <- occupation %>%
  mutate(annee = as.integer(annee),
         proportion_culture = as.numeric(proportion_culture)) %>%
  filter(!annee %in% 2019:2022) %>%                   # exclut les années incomplètes
  filter(substr(commune_code, 1, 2) == "52") %>%      # communes de Haute-Marne uniquement
  group_by(commune_code, commune_nom, annee, risque_fuite) %>%
  summarise(part_risque = sum(proportion_culture), .groups = "drop") %>%
  complete(nesting(commune_code, commune_nom), annee, risque_fuite,
           fill = list(part_risque = 0))              # niveau absent = 0 %

# Contrôles
n_distinct(risque_annuel$commune_code)     # nombre de communes (environ 425 attendues)
summary(risque_annuel$part_risque)         # le Max doit être <= 1

# ---- 3. Pente de Sen sur les vraies années ----
pente_sen <- function(valeur, annee) {
  paires <- combn(length(valeur), 2)
  median((valeur[paires[2, ]] - valeur[paires[1, ]]) /
           (annee[paires[2, ]]  - annee[paires[1, ]]))
}

# ---- 4. Mann-Kendall par commune et par niveau de risque ----
tendance_risque <- risque_annuel %>%
  arrange(commune_code, risque_fuite, annee) %>%
  group_by(commune_code, commune_nom, risque_fuite) %>%
  filter(n() >= 6) %>%
  summarise(
    n_annees     = n(),
    part_debut   = round(first(part_risque) * 100, 1),
    part_fin     = round(last(part_risque) * 100, 1),
    constante    = n_distinct(part_risque) == 1,
    p_value      = if (n_distinct(part_risque) > 1) mk.test(part_risque)$p.value else NA_real_,
    pente_pts_an = round(pente_sen(part_risque, annee) * 100, 2),
    .groups      = "drop"
  ) %>%
  mutate(tendance = case_when(
    constante                         ~ "part constante",
    p_value < 0.05 & pente_pts_an > 0 ~ "hausse",
    p_value < 0.05 & pente_pts_an < 0 ~ "baisse",
    TRUE                              ~ "pas de tendance significative"
  ))

# ---- 5. Vérification rapide ----
print(tendance_risque)
table(tendance_risque$risque_fuite, tendance_risque$tendance)

# ---- 6. Renvoi dans Postgres ----
dbWriteTable(con, "tendance_risque_commune", tendance_risque, overwrite = TRUE)
