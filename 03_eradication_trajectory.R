# 03_eradication_trajectory.R
#
# Project: Polio Eradication



# 1. Load packages 

library(tidyverse)
library(here)
library(scales)


# 2. Create output directories if required 

if (!dir.exists(here("plots"))) {
  dir.create(
    here("plots"),
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



# 3. Import processed country-level data

polio_country <- read_csv(
  here(
    "data",
    "processed",
    "polio_country.csv"
  ),
  show_col_types = FALSE
)


# 4. Import annual global trajectory

annual_global <- read_csv(
  here(
    "data",
    "processed",
    "polio_annual_global.csv"
  ),
  show_col_types = FALSE
)


# LONG-TERM DECLINE



# 5. Calculate annual change in estimated cases

annual_trajectory <- annual_global |>
  arrange(year) |>
  mutate(
    
    previous_year_cases =
      lag(
        total_estimated_cases
      ),
    
    absolute_change =
      total_estimated_cases -
      previous_year_cases,
    
    percent_change =
      100 *
      absolute_change /
      previous_year_cases,
    
    log10_cases =
      log10(
        total_estimated_cases + 1
      )
  )


print(
  annual_trajectory,
  n = Inf
)


# 6. Calculate overall change from first to last year

overall_decline <- annual_trajectory |>
  summarise(
    
    first_year =
      first(year),
    
    first_year_cases =
      first(total_estimated_cases),
    
    last_year =
      last(year),
    
    last_year_cases =
      last(total_estimated_cases),
    
    absolute_change =
      last_year_cases -
      first_year_cases,
    
    percent_change =
      100 *
      (
        last_year_cases -
          first_year_cases
      ) /
      first_year_cases
  )


overall_decline


# MINIMUM BURDEN



# 7. Identify year with lowest estimated global burden

minimum_burden <- annual_trajectory |>
  slice_min(
    order_by = total_estimated_cases,
    n = 1,
    with_ties = FALSE
  )


minimum_burden


# 8. Calculate change after minimum burden

minimum_year <- minimum_burden$year

minimum_cases <- minimum_burden$total_estimated_cases


post_minimum_change <- annual_trajectory |>
  filter(
    year >= minimum_year
  ) |>
  mutate(
    
    change_from_minimum =
      total_estimated_cases -
      minimum_cases,
    
    percent_change_from_minimum =
      100 *
      change_from_minimum /
      minimum_cases
  )


print(
  post_minimum_change,
  n = Inf
)


# COUNTRIES WITH CASES



# 9. Plot number of countries with positive estimated cases

plot_positive_countries <- annual_trajectory |>
  ggplot(
    aes(
      x = year,
      y = n_entities_with_cases
    )
  ) +
  geom_line(
    linewidth = 0.9
  ) +
  geom_point(
    size = 1.8
  ) +
  labs(
    title = "Number of countries with estimated polio cases declined markedly",
    subtitle = "Country-level observations with more than zero estimated cases",
    x = "Year",
    y = "Countries with estimated cases"
  ) +
  theme_minimal(
    base_size = 12
  )


plot_positive_countries


ggsave(
  here(
    "plots",
    "01_countries_with_estimated_polio_cases.png"
  ),
  plot_positive_countries,
  width = 10,
  height = 6,
  dpi = 300
)


# GLOBAL BURDEN



# 10. Plot estimated global polio cases

plot_global_cases <- annual_trajectory |>
  ggplot(
    aes(
      x = year,
      y = total_estimated_cases
    )
  ) +
  geom_line(
    linewidth = 0.9
  ) +
  labs(
    title = "Estimated global polio burden declined dramatically from 1980",
    subtitle = "Country-level estimated cases summed annually",
    x = "Year",
    y = "Estimated cases"
  ) +
  scale_y_continuous(
    labels = label_comma()
  ) +
  theme_minimal(
    base_size = 12
  )


plot_global_cases


ggsave(
  here(
    "plots",
    "02_global_polio_cases_over_time.png"
  ),
  plot_global_cases,
  width = 10,
  height = 6,
  dpi = 300
)


# LOG-SCALE TRAJECTORY



# 11. Plot global burden on a logarithmic scale

plot_global_log <- annual_trajectory |>
  ggplot(
    aes(
      x = year,
      y = total_estimated_cases
    )
  ) +
  geom_line(
    linewidth = 0.9
  ) +
  geom_point(
    size = 1.5
  ) +
  scale_y_log10(
    labels = label_comma()
  ) +
  labs(
    title = "The polio eradication trajectory spans several orders of magnitude",
    subtitle = "Estimated global cases shown on a logarithmic scale",
    x = "Year",
    y = "Estimated cases (log scale)"
  ) +
  theme_minimal(
    base_size = 12
  )


plot_global_log


ggsave(
  here(
    "plots",
    "03_global_polio_cases_log_scale.png"
  ),
  plot_global_log,
  width = 10,
  height = 6,
  dpi = 300
)


# ZERO-CASE PROPORTION



# 12. Plot proportion of observed countries with zero estimated cases

plot_zero_proportion <- annual_trajectory |>
  ggplot(
    aes(
      x = year,
      y = proportion_entities_zero
    )
  ) +
  geom_line(
    linewidth = 0.9
  ) +
  geom_point(
    size = 1.5
  ) +
  scale_y_continuous(
    limits = c(
      0,
      100
    ),
    labels = label_percent(
      scale = 1
    )
  ) +
  labs(
    title = "An increasing proportion of countries reached zero estimated cases",
    subtitle = "Percentage of observed country-level entities with zero estimated polio cases",
    x = "Year",
    y = "Countries with zero estimated cases"
  ) +
  theme_minimal(
    base_size = 12
  )


plot_zero_proportion


ggsave(
  here(
    "plots",
    "04_proportion_countries_zero_cases.png"
  ),
  plot_zero_proportion,
  width = 10,
  height = 6,
  dpi = 300
)


# ANNUAL PERCENTAGE CHANGE



# 13. Plot year-to-year percentage change

plot_annual_change <- annual_trajectory |>
  filter(
    !is.na(percent_change)
  ) |>
  ggplot(
    aes(
      x = year,
      y = percent_change
    )
  ) +
  geom_hline(
    yintercept = 0,
    linetype = "dashed"
  ) +
  geom_col() +
  labs(
    title = "Year-to-year change in estimated global polio cases",
    subtitle = "Negative values indicate annual declines; positive values indicate increases",
    x = "Year",
    y = "Annual change (%)"
  ) +
  theme_minimal(
    base_size = 12
  )


plot_annual_change


ggsave(
  here(
    "plots",
    "05_annual_percentage_change.png"
  ),
  plot_annual_change,
  width = 11,
  height = 6,
  dpi = 300
)


# KEY YEARS



# 14. Select key years in the eradication trajectory

key_years <- annual_trajectory |>
  filter(
    year %in% c(
      1980,
      1990,
      2000,
      2010,
      2016,
      2020
    )
  ) |>
  select(
    year,
    total_estimated_cases,
    n_entities_with_cases,
    n_entities_zero,
    proportion_entities_zero
  )


key_years


# COUNTRY BURDEN AT KEY TIME POINTS



# 15. Identify highest-burden countries in selected years

key_country_burden <- polio_country |>
  filter(
    year %in% c(
      1980,
      1990,
      2000,
      2010,
      2016,
      2020
    ),
    estimated_cases > 0
  ) |>
  group_by(year) |>
  slice_max(
    order_by = estimated_cases,
    n = 10,
    with_ties = FALSE
  ) |>
  ungroup() |>
  arrange(
    year,
    desc(estimated_cases)
  )


print(
  key_country_burden,
  n = Inf
)


# YEARS WITH LARGEST DECLINES



# 16. Identify largest proportional annual declines

largest_annual_declines <- annual_trajectory |>
  filter(
    !is.na(percent_change)
  ) |>
  arrange(
    percent_change
  ) |>
  slice_head(
    n = 10
  )


largest_annual_declines


# YEARS WITH LARGEST INCREASES


# 17. Identify largest proportional annual increases

largest_annual_increases <- annual_trajectory |>
  filter(
    !is.na(percent_change)
  ) |>
  arrange(
    desc(
      percent_change
    )
  ) |>
  slice_head(
    n = 10
  )


largest_annual_increases


# SAVE OUTPUTS



write_csv(
  annual_trajectory,
  here(
    "data",
    "processed",
    "polio_annual_trajectory.csv"
  )
)


write_csv(
  overall_decline,
  here(
    "tables",
    "polio_overall_decline.csv"
  )
)


write_csv(
  minimum_burden,
  here(
    "tables",
    "polio_minimum_burden.csv"
  )
)


write_csv(
  post_minimum_change,
  here(
    "tables",
    "polio_post_minimum_change.csv"
  )
)


write_csv(
  key_years,
  here(
    "tables",
    "polio_key_years.csv"
  )
)


write_csv(
  key_country_burden,
  here(
    "tables",
    "polio_key_country_burden.csv"
  )
)


write_csv(
  largest_annual_declines,
  here(
    "tables",
    "polio_largest_annual_declines.csv"
  )
)


write_csv(
  largest_annual_increases,
  here(
    "tables",
    "polio_largest_annual_increases.csv"
  )
)



message(
  "Polio eradication trajectory analysis complete."
)