# 📌 Détection des captages en dégradation nitrates et ciblage des actions préventives en Haute-Marne

## Business Problem

Chaque année, les maîtres d'ouvrage chargés de la distribution d'eau potable reçoivent des alertes de l'ARS signalant des dépassements de la norme de 50 mg/L en nitrates, rendant l'eau impropre à la consommation.

Ces dépassements entraînent des coûts non prévus : distribution d'eau en bouteille aux usagers, recherche de ressources de substitution, interconnexions, puis, si la pollution s'installe, investissement et fonctionnement d'une unité de traitement (dénitrification).

À l'inverse, les actions préventives menées en amont, sur l'aire d'alimentation du captage (accompagnement des agriculteurs, couverts d'interculture, gestion de la fertilisation, maintien des prairies), coûtent nettement moins cher. Une étude de l'Agence de l'eau Seine-Normandie (2026), portant sur 21 aires d'alimentation de captages, estime que traiter une eau polluée par les nitrates et les pesticides coûte **en moyenne 3 fois plus cher** que d'agir à la source, et **environ 13 fois plus cher pour le service d'eau potable** une fois les aides déduites ([source](https://www.banquedesterritoires.fr/pollution-de-leau-le-curatif-trois-fois-plus-couteux-que-le-preventif-selon-une-nouvelle-etude)). Mais elles mettent du temps à produire leurs effets, et les moyens d'animation sont limités. **Il faut donc savoir où agir en priorité, et le plus tôt possible.**

## Project Objective

**Quelles questions cette analyse cherche-t-elle à résoudre ?**

- Quels captages voient leur concentration en nitrates augmenter de façon significative ?
- L'évolution récente de l'assolement (cultures à risque de fuite d'azote) explique-t-elle ces hausses ?

**Quelles décisions doit-elle éclairer ?**

- **Prioriser les communes et captages** où engager l'accompagnement agricole en premier.
- **Choisir les bons leviers d'action** : faut-il agir sur la nature des cultures ou sur les pratiques ?
- À terme, **estimer le coût de la prévention** par captage ciblé et le comparer au coût du curatif.

## About the Dataset

| Élément | Détail |
|---|---|
| **Sources** | ADES / Hub'Eau (qualité des eaux souterraines), Registre parcellaire graphique (IGN), notices Telepac (codes cultures), limites communales (data.gouv.fr, référentiel administratif) |
| **Volume** | 7 326 analyses de nitrates sur 712 captages ; après sélection d'un captage de référence par commune, 5 194 analyses retenues (71 %) ; RPG : environ 58 000 parcelles par an |
| **Période** | Nitrates : 1996 – 2026 ; RPG : 2015 – 2024 |
| **Variables clés** | Identifiant du captage, date et résultat d'analyse, code commune ; code culture, surface et géométrie de la parcelle |
| **Limites** | RPG 2019 à 2022 incomplets après import, donc exclus ; 1 à 2 prélèvements par an pour la plupart des captages ; RPG limité aux surfaces déclarées à la PAC |
| **Qualité des données** | Analyses sans résultat exclues ; communes associées et déléguées rattachées à leur commune nouvelle ; table de correspondance des codes cultures corrigée à partir des notices officielles (176 codes sur 215 étaient mal classés) ; reprojection des couches en Lambert 93 ; SAU recalculée pour chaque commune et chaque année ; parcelles hors Haute-Marne exclues |

## Tools Used

- **PostgreSQL / PostGIS** : import, nettoyage, jointures spatiales, indicateurs
- **QGIS** : préparation et contrôle des couches géographiques
- **R** : tests statistiques et graphiques (`dplyr`, `trend`, `ggplot2`)

## Methodology

1. **Data cleaning** : import des analyses dans une table de staging, extraction des nitrates (code SANDRE 1340), typage, exclusion des valeurs manquantes, harmonisation des codes communes.
2. **Data validation** : contrôle des doublons, de la complétude des RPG par année (surface totale, nombre de parcelles), cohérence des parts de SAU (somme égale à 100 % par commune et par année).
3. **Indicateurs** : médiane annuelle des nitrates par captage, classement des analyses (conforme < 25 mg/L, sensible 25 à 50 mg/L, dépassement > 50 mg/L), part de SAU par niveau de risque de fuite d'azote.
4. **Tendances** : test de Mann-Kendall et pente de Sen sur les médianes annuelles (nitrates) et sur les parts de SAU (cultures). Méthodes non paramétriques, adaptées à des données non normales et irrégulières.
5. **Croisement** : corrélation de Spearman entre la tendance des nitrates et la tendance des cultures à risque, commune par commune.
6. **Business interpretation** : traduction des résultats en priorités d'action.

Le détail de la méthode, les compromis sur la qualité des données et les hypothèses posées sont présentés dans [METHODOLOGIE.md](METHODOLOGIE.md).

## Key Findings

**1. Une partie des captages est en hausse significative.**
Sur les 122 captages testés (un par commune, au moins 8 années de mesures) :

| Tendance | Captages |
|---|---|
| Hausse significative | 21 (17 %) |
| Baisse significative | 9 (7 %) |
| Pas de tendance significative | 92 (75 %) |

Les captages en hausse progressent en médiane de **0,27 mg/L par an**, soit environ +2,7 mg/L en dix ans.
Ce sont ces captages qui risquent de franchir le seuil de 50 mg/L dans les prochaines années, s'ils ne l'ont pas déjà fait.

**2. L'assolement est stable, et quand il évolue, c'est vers moins de risque.**
Sur les 426 communes du département, entre 2015 et 2024 :

| Niveau de risque | Baisse | Hausse | Pas de tendance significative |
|---|---|---|---|
| Élevé (colza, maïs) | 18 (4 %) | 0 | 407 (96 %) |
| Moyen (céréales, autres cultures annuelles) | 5 (1 %) | 3 (1 %) | 418 (98 %) |
| Faible (prairies, légumineuses fourragères, jachères) | 5 (1 %) | 79 (19 %) | 342 (80 %) |

Aucune commune n'a vu sa part de colza et de maïs augmenter. Près d'une commune sur cinq a gagné des surfaces à faible risque.

**3. L'évolution récente de l'assolement n'explique pas les hausses de nitrates.**
Aucune corrélation n'a été trouvée entre l'évolution de la part de cultures à risque élevé et la tendance des nitrates, commune par commune (ρ de Spearman = 0,02 ; p = 0,82 ; environ 120 communes disposant des deux informations). La grande majorité des communes voit sa part de colza et de maïs reculer légèrement, y compris parmi celles dont les nitrates augmentent : **l'assolement s'améliore, mais l'eau ne suit pas encore.**

**4. Ce que ce résultat veut dire.**
Les hausses observées dans l'eau ne sont pas la conséquence de changements de cultures récents. Elles reflètent plus probablement :
- **des pressions plus anciennes**, qui arrivent seulement maintenant aux captages en raison du temps de transfert de l'azote vers la nappe (plusieurs années, voire décennies) ;
- **les pratiques agricoles** (fertilisation, gestion de l'interculture, retournement de prairies), que le RPG ne décrit pas ;
- **la vulnérabilité propre à chaque captage** (type de sol, profondeur, nature de l'aquifère).

## Business Impact

**Comment l'analyse répond-elle au problème ?**
Elle fournit une **liste objective et priorisée des captages en dégradation**, fondée sur une méthode statistique robuste, plutôt que d'attendre les dépassements signalés par l'ARS.

**Quelle valeur crée-t-elle ?**
- **Cibler les moyens d'animation** là où la qualité de l'eau se dégrade réellement, au lieu de les répartir uniformément.
- **Agir avant le dépassement** : compte tenu du temps de transfert, une action lancée aujourd'hui ne produira ses effets que dans plusieurs années. Plus la détection est précoce, plus on a de chances d'éviter le recours au curatif.
- **Éviter une fausse piste** : l'absence de lien avec l'assolement récent montre qu'un simple suivi des surfaces de colza ou de maïs ne suffit pas comme indicateur d'alerte. C'est l'eau elle-même qu'il faut surveiller.
- **Donner une lecture juste des efforts en cours** : l'assolement évolue déjà vers moins de risque, sans effet visible dans l'eau pour l'instant. Cela invite à maintenir les efforts dans la durée plutôt qu'à conclure à leur inefficacité.

**Quelles décisions deviennent possibles ?**
- Définir l'ordre de priorité des communes à accompagner.
- Orienter l'accompagnement vers les **pratiques**, et pas seulement vers la nature des cultures.
- Préparer une comparaison des coûts prévention / curatif, captage par captage.

## Recommendations

1. **Engager l'accompagnement agricole en priorité dans les communes dont le captage est en hausse significative**, en commençant par celles qui sont le plus proches du seuil de 50 mg/L.
2. **Agir sur les pratiques plutôt que sur le seul choix des cultures** : couverture des sols en interculture, ajustement de la fertilisation, maintien des prairies.
3. **Utiliser la tendance des nitrates comme indicateur d'alerte principal**, et non l'évolution de l'assolement.
4. **Renforcer le suivi des captages peu échantillonnés** : avec 1 à 2 analyses par an, beaucoup de captages ne permettent pas de détecter une tendance, ce qui crée des angles morts.

## Next Steps

- **Prioriser finement** : croiser la pente des nitrates avec le niveau actuel, la population desservie et l'existence de ressources de substitution, pour obtenir un score de priorité par captage.
- **Changer d'échelle** : travailler sur les aires d'alimentation de captage (AAC) plutôt que sur les communes.
- **Comparer les niveaux plutôt que les évolutions** : la part moyenne de cultures à risque d'une commune est-elle liée à son niveau de nitrates ?
- **Estimer les coûts** : coût de l'animation et des mesures agro-environnementales par captage, comparé au coût d'une unité de traitement.
- **Automatiser** : mise à jour annuelle des tendances via l'API Hub'Eau, avec un tableau de bord de suivi des captages prioritaires.
- **Compléter les données** : réimporter les RPG 2019 à 2022, intégrer des données de pratiques et d'hydrogéologie.

---

*Les scripts R ont été rédigés avec l'aide d'une IA. La question, les choix méthodologiques, la préparation des données en SQL et la validation des résultats sont personnels.*
