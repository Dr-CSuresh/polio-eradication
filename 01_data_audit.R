# 01_data_audit.R
#
# Project: Polio Eradication



# 1. Load packages 

library(tidyverse)
library(here)


# 2. Create output directory if required 

if (!dir.exists(here("tables"))) {
  dir.create(
    here("tables"),
    recursive = TRUE
  )
}


# IMPORT DATA



# 3. Import only variables required for the polio analysis 

polio_raw <- read_csv(
  here(
    "data",
    "raw",
    "1- the-number-of-cases-of-infectious-diseases.csv"
  ),
  col_select = c(
    Entity,
    Code,
    Year,
    `Total (estimated) polio cases`
  ),
  col_types = cols(
    Entity = col_character(),
    Code = col_character(),
    Year = col_double(),
    `Total (estimated) polio cases` = col_double()
  )
)


# CHECK IMPORT



# 4. Inspect dataset structure 

glimpse(polio_raw)


# 5. Check parsing problems 

polio_parsing_problems <- problems(
  polio_raw
)

polio_parsing_problems


# DATASET COVERAGE



# 6. Summarise available polio observations 

polio_summary <- polio_raw |>
  filter(
    !is.na(`Total (estimated) polio cases`)
  ) |>
  summarise(
    
    n_observations = n(),
    
    first_year =
      min(
        Year,
        na.rm = TRUE
      ),
    
    last_year =
      max(
        Year,
        na.rm = TRUE
      ),
    
    n_entities =
      n_distinct(Entity),
    
    n_codes =
      n_distinct(
        Code,
        na.rm = TRUE
      )
  )


polio_summary


# DUPLICATES



# 7. Check duplicate entity-year observations 

polio_duplicates <- polio_raw |>
  filter(
    !is.na(`Total (estimated) polio cases`)
  ) |>
  count(
    Entity,
    Code,
    Year,
    name = "n"
  ) |>
  filter(
    n > 1
  )


polio_duplicates


# MISSING DATA



# 8. Assess missingness 

polio_missingness <- polio_raw |>
  summarise(
    across(
      everything(),
      ~ sum(is.na(.x))
    )
  ) |>
  pivot_longer(
    cols = everything(),
    names_to = "variable",
    values_to = "n_missing"
  ) |>
  mutate(
    percent_missing =
      round(
        100 *
          n_missing /
          nrow(polio_raw),
        2
      )
  )


polio_missingness


# ENTITY CHECKS



# 9. Identify entities without country codes 

entities_without_codes <- polio_raw |>
  filter(
    is.na(Code)
  ) |>
  distinct(
    Entity,
    Code
  ) |>
  arrange(Entity)


print(
  entities_without_codes,
  n = Inf
)


# 10. Identify coded aggregate entities 

coded_entities <- polio_raw |>
  filter(
    !is.na(Code)
  ) |>
  distinct(
    Entity,
    Code
  ) |>
  arrange(Entity)


print(
  coded_entities,
  n = Inf
)


# TEMPORAL COVERAGE



# 11. Count available observations by year

polio_records_by_year <- polio_raw |>
  filter(
    !is.na(`Total (estimated) polio cases`)
  ) |>
  count(
    Year,
    name = "n_entities"
  ) |>
  arrange(Year)


print(
  polio_records_by_year,
  n = Inf
)


# BASIC VALUE CHECKS



# 12. Check for negative estimated case counts 

negative_cases <- polio_raw |>
  filter(
    `Total (estimated) polio cases` < 0
  )


negative_cases


# 13. Count zero-case observations 

zero_case_summary <- polio_raw |>
  filter(
    !is.na(`Total (estimated) polio cases`)
  ) |>
  summarise(
    
    n_observations = n(),
    
    n_zero =
      sum(
        `Total (estimated) polio cases` == 0,
        na.rm = TRUE
      ),
    
    percent_zero =
      100 *
      n_zero /
      n_observations
  )


zero_case_summary


# 14. Examine largest estimated polio burdens 

largest_polio_observations <- polio_raw |>
  filter(
    !is.na(`Total (estimated) polio cases`)
  ) |>
  arrange(
    desc(
      `Total (estimated) polio cases`
    )
  ) |>
  slice_head(
    n = 25
  )


print(
  largest_polio_observations,
  n = Inf
)


# ZERO-CASE PATTERNS



# 15. Identify first and last observed year for each entity

entity_coverage <- polio_raw |>
  filter(
    !is.na(`Total (estimated) polio cases`)
  ) |>
  group_by(
    Entity,
    Code
  ) |>
  summarise(
    
    first_year =
      min(Year),
    
    last_year =
      max(Year),
    
    years_observed =
      n(),
    
    years_with_zero_cases =
      sum(
        `Total (estimated) polio cases` == 0
      ),
    
    years_with_cases =
      sum(
        `Total (estimated) polio cases` > 0
      ),
    
    .groups = "drop"
  ) |>
  arrange(
    desc(years_with_cases)
  )


print(
  entity_coverage,
  n = 30
)



# SAVE AUDIT OUTPUTS



write_csv(
  polio_summary,
  here(
    "tables",
    "polio_dataset_summary.csv"
  )
)


write_csv(
  polio_missingness,
  here(
    "tables",
    "polio_missingness.csv"
  )
)


write_csv(
  polio_duplicates,
  here(
    "tables",
    "polio_duplicates.csv"
  )
)


write_csv(
  polio_records_by_year,
  here(
    "tables",
    "polio_records_by_year.csv"
  )
)


write_csv(
  entity_coverage,
  here(
    "tables",
    "polio_entity_coverage.csv"
  )
)


write_csv(
  largest_polio_observations,
  here(
    "tables",
    "largest_polio_observations.csv"
  )
)



message(
  "Polio data audit complete."
)