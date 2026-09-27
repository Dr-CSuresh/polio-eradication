# 02_data_cleaning.R
#
# Project: Polio Eradication


# 1. Load packages 

library(tidyverse)
library(here)


# 2. Create output directories 

if (!dir.exists(here("data", "processed"))) {
  dir.create(
    here("data", "processed"),
    recursive = TRUE
  )
}

if (!dir.exists(here("tables"))) {
  dir.create(
    here("tables"),
    recursive = TRUE
  )
}



# IMPORT DATA



# 3. Import only variables needed for this project 

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


# STANDARDISE VARIABLES



# 4. Rename variables 

polio_clean <- polio_raw |>
  transmute(
    entity = Entity,
    code = Code,
    year = Year,
    estimated_cases = `Total (estimated) polio cases`
  )



# DOCUMENT EXCLUSIONS



# 5. Identify non-country / aggregate observations 
# Main analysis excludes: entities without a country code and OWID-specific aggregate or historical entity codes
# These observations are retained in an exclusions table for transparency.

excluded_entities <- polio_clean |>
  filter(
    is.na(code) |
      str_detect(
        code,
        "^OWID_"
      )
  ) |>
  distinct(
    entity,
    code
  ) |>
  arrange(entity)


print(
  excluded_entities,
  n = Inf
)


write_csv(
  excluded_entities,
  here(
    "tables",
    "excluded_polio_entities.csv"
  )
)



# COUNTRY-LEVEL DATASET



# 6. Restrict to coded country/territory observations 

polio_country <- polio_clean |>
  filter(
    !is.na(code),
    !str_detect(
      code,
      "^OWID_"
    ),
    !is.na(estimated_cases)
  ) |>
  arrange(
    entity,
    year
  )


glimpse(polio_country)



# QUALITY CHECKS AFTER FILTERING



# 7. Check for duplicate country-year observations

country_duplicates <- polio_country |>
  count(
    entity,
    code,
    year,
    name = "n"
  ) |>
  filter(
    n > 1
  )


country_duplicates


# 8. Check negative estimated case counts 

negative_country_cases <- polio_country |>
  filter(
    estimated_cases < 0
  )


negative_country_cases



# DERIVED VARIABLES



# 9. Create analysis variables

polio_country <- polio_country |>
  mutate(
    
    positive_cases =
      estimated_cases > 0,
    
    zero_cases =
      estimated_cases == 0,
    
    log10_cases_plus1 =
      log10(
        estimated_cases + 1
      )
  )



# COUNTRY-LEVEL COVERAGE SUMMARY



# 10. Summarise each country's observation history

country_summary <- polio_country |>
  group_by(
    entity,
    code
  ) |>
  summarise(
    
    first_observed_year =
      min(year),
    
    last_observed_year =
      max(year),
    
    years_observed =
      n(),
    
    years_positive =
      sum(
        positive_cases
      ),
    
    years_zero =
      sum(
        zero_cases
      ),
    
    total_estimated_cases =
      sum(
        estimated_cases,
        na.rm = TRUE
      ),
    
    maximum_annual_cases =
      max(
        estimated_cases,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  ) |>
  arrange(
    desc(
      total_estimated_cases
    )
  )


print(
  country_summary,
  n = 30
)



# ANNUAL GLOBAL TRAJECTORY



# 11. Summarise country-level burden by year 

annual_global <- polio_country |>
  group_by(year) |>
  summarise(
    
    n_entities_observed =
      n(),
    
    n_entities_with_cases =
      sum(
        positive_cases
      ),
    
    n_entities_zero =
      sum(
        zero_cases
      ),
    
    total_estimated_cases =
      sum(
        estimated_cases,
        na.rm = TRUE
      ),
    
    .groups = "drop"
  ) |>
  mutate(
    
    proportion_entities_zero =
      100 *
      n_entities_zero /
      n_entities_observed,
    
    proportion_entities_positive =
      100 *
      n_entities_with_cases /
      n_entities_observed
  )


print(
  annual_global,
  n = Inf
)



# VALIDATE AGAINST PROVIDED WORLD SERIES



# 12. Extract World observations 
#
# The source dataset contains a World series but provides a useful cross-check against the sum of country-level estimates.

world_series <- polio_clean |>
  filter(
    code == "OWID_WRL",
    !is.na(estimated_cases)
  ) |>
  select(
    year,
    world_estimated_cases = estimated_cases
  )


# 13. Compare country sum with World series 

world_validation <- annual_global |>
  select(
    year,
    country_sum = total_estimated_cases
  ) |>
  left_join(
    world_series,
    by = "year"
  ) |>
  mutate(
    
    absolute_difference =
      country_sum -
      world_estimated_cases,
    
    percent_difference =
      if_else(
        world_estimated_cases > 0,
        100 *
          absolute_difference /
          world_estimated_cases,
        NA_real_
      )
  )


print(
  world_validation,
  n = Inf
)


# 14. Summarise agreement 

world_validation_summary <- world_validation |>
  summarise(
    
    n_years_compared =
      sum(
        !is.na(
          world_estimated_cases
        )
      ),
    
    median_absolute_difference =
      median(
        abs(
          absolute_difference
        ),
        na.rm = TRUE
      ),
    
    median_percent_difference =
      median(
        abs(
          percent_difference
        ),
        na.rm = TRUE
      ),
    
    maximum_percent_difference =
      max(
        abs(
          percent_difference
        ),
        na.rm = TRUE
      )
  )


world_validation_summary


# IDENTIFY FIRST ZERO YEARS



# 15. First observed zero-case year 
#
# IMPORTANT: This is only the first observed year with zero estimated cases.
# Sustained-zero definitions will be constructed later using consecutive-year criteria.

first_zero_year <- polio_country |>
  filter(
    zero_cases
  ) |>
  group_by(
    entity,
    code
  ) |>
  summarise(
    
    first_zero_year =
      min(year),
    
    .groups = "drop"
  )


print(
  first_zero_year,
  n = 30
)


# SAVE PROCESSED DATA



write_csv(
  polio_country,
  here(
    "data",
    "processed",
    "polio_country.csv"
  )
)


write_csv(
  annual_global,
  here(
    "data",
    "processed",
    "polio_annual_global.csv"
  )
)


write_csv(
  country_summary,
  here(
    "tables",
    "polio_country_summary.csv"
  )
)


write_csv(
  world_validation,
  here(
    "tables",
    "polio_world_series_validation.csv"
  )
)


write_csv(
  world_validation_summary,
  here(
    "tables",
    "polio_world_validation_summary.csv"
  )
)


write_csv(
  first_zero_year,
  here(
    "tables",
    "polio_first_zero_year.csv"
  )
)



message(
  "Polio data cleaning complete."
)