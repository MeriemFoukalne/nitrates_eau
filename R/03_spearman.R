# =========================================================
# 03 - Lien entre l'évolution des cultures à risque et celle des nitrates
# Corrélation de Spearman, commune par commune
# =========================================================

library(dplyr)
library(ggplot2)
library(DBI)

# ---- 1. Import des deux tables de tendances ----
nitrates <- dbReadTable(con, "tendance_mediane")          # tendance des nitrates par commune
cultures <- dbReadTable(con, "tendance_risque_commune")   # tendance des cultures par commune

# ---- 2. Association des deux, commune par commune ----
croisement <- cultures %>%
  filter(risque_fuite == "élevé") %>%
  select(commune_code, commune_nom, pente_cultures = pente_pts_an) %>%
  inner_join(
    nitrates %>% select(code_commune, pente_nitrates = pente_sen),
    by = c("commune_code" = "code_commune")
  )

nrow(croisement)   # nombre de communes qui ont les deux informations

# ---- 3. Corrélation de Spearman ----
cor.test(croisement$pente_cultures, croisement$pente_nitrates,
         method = "spearman", exact = FALSE)

# ---- 4. Graphique ----
ggplot(croisement, aes(x = pente_cultures, y = pente_nitrates)) +
  geom_point() +
  geom_hline(yintercept = 0, linetype = "dashed") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(x = "Évolution de la part de SAU en risque élevé (points / an)",
       y = "Évolution des nitrates (mg/L / an)",
       title = "Cultures à risque et nitrates, par commune")
