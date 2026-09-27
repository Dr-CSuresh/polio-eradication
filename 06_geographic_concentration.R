# 06_geographic_concentration.R
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



# 3. Import country-level polio data

polio_country <- read_csv(
  here(
    "data",
    "processed",
    "polio_country.csv"
  ),
  show_col_types = FALSE
)


# COUNTRY SHARES



# 4. Calculate each country's share of annual estimated cases

country_shares <- polio_country |>
  group_by(year) |>
  mutate(
    
    annual_total_cases =
      sum(
        estimated_cases,
        na.rm = TRUE
      ),
    
    burden_share =
      if_else(
        annual_total_cases > 0,
        estimated_cases /
          annual_total_cases,
        0
      )
  ) |>
  ungroup()


# GEOGRAPHIC CONCENTRATION



# 5. Calculate annual concentration measures

annual_concentration <- country_shares |>
  group_by(year) |>
  summarise(
    
    total_estimated_cases =
      first(
        annual_total_cases
      ),
    
    n_entities_observed =
      n(),
    
    n_entities_with_cases =
      sum(
        estimated_cases > 0
      ),
    
    HHI =
      sum(
        burden_share^2,
        na.rm = TRUE
      ),
    
    effective_number_countries =
      if_else(
        HHI > 0,
        1 / HHI,
        NA_real_
      ),
    
    top_country_share =
      max(
        burden_share,
        na.rm = TRUE
      ) *
      100,
    
    top_three_share =
      sum(
        sort(
          burden_share,
          decreasing = TRUE
        )[1:min(
          3,
          length(
            burden_share
          )
        )],
        na.rm = TRUE
      ) *
      100,
    
    top_five_share =
      sum(
        sort(
          burden_share,
          decreasing = TRUE
        )[1:min(
          5,
          length(
            burden_share
          )
        )],
        na.rm = TRUE
      ) *
      100,
    
    .groups = "drop"
  )


print(
  annual_concentration,
  n = Inf
)


# INTERPRETATION OF HHI



# 6. Identify years with greatest concentration

highest_concentration <- annual_concentration |>
  arrange(
    desc(HHI)
  ) |>
  slice_head(
    n = 10
  )


highest_concentration


# 7. Identify years with lowest concentration

lowest_concentration <- annual_concentration |>
  arrange(HHI) |>
  slice_head(
    n = 10
  )


lowest_concentration


# DOMINANT COUNTRIES



# 8. Identify highest-burden country in each year

annual_top_country <- country_shares |>
  group_by(year) |>
  slice_max(
    order_by = estimated_cases,
    n = 1,
    with_ties = FALSE
  ) |>
  ungroup() |>
  transmute(
    
    year,
    
    entity,
    
    code,
    
    estimated_cases,
    
    burden_share_percent =
      burden_share *
      100
  )


print(
  annual_top_country,
  n = Inf
)


# KEY YEARS



# 9. Summarise concentration at key points in the trajectory

key_concentration_years <- annual_concentration |>
  filter(
    year %in% c(
      1980,
      1990,
      2000,
      2010,
      2016,
      2020
    )
  )


key_concentration_years


# 10. Identify leading countries in key years

key_country_shares <- country_shares |>
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
    n = 5,
    with_ties = FALSE
  ) |>
  ungroup() |>
  mutate(
    
    burden_share_percent =
      burden_share *
      100
  ) |>
  select(
    year,
    entity,
    code,
    estimated_cases,
    burden_share_percent
  ) |>
  arrange(
    year,
    desc(
      estimated_cases
    )
  )


print(
  key_country_shares,
  n = Inf
)


# HHI OVER TIME



# 11. Plot geographic concentration over time

plot_hhi <- annual_concentration |>
  ggplot(
    aes(
      x = year,
      y = HHI
    )
  ) +
  geom_line(
    linewidth = 0.9
  ) +
  geom_point(
    size = 1.5
  ) +
  labs(
    title = "Geographic concentration of estimated polio burden varied over time",
    subtitle = "Herfindahl-Hirschman Index based on country shares of annual estimated cases",
    x = "Year",
    y = "Herfindahl-Hirschman Index",
    caption = "Higher values indicate greater concentration of estimated burden in fewer countries."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_hhi


ggsave(
  here(
    "plots",
    "10_polio_geographic_concentration_hhi.png"
  ),
  plot_hhi,
  width = 10,
  height = 6,
  dpi = 300
)


# EFFECTIVE NUMBER OF COUNTRIES



# 12. Plot effective number of burden-contributing countries

plot_effective_countries <- annual_concentration |>
  ggplot(
    aes(
      x = year,
      y = effective_number_countries
    )
  ) +
  geom_line(
    linewidth = 0.9
  ) +
  geom_point(
    size = 1.5
  ) +
  labs(
    title = "Effective number of countries contributing to estimated polio burden",
    subtitle = "Calculated as the inverse of the annual HHI",
    x = "Year",
    y = "Effective number of countries"
  ) +
  theme_minimal(
    base_size = 12
  )


plot_effective_countries


ggsave(
  here(
    "plots",
    "11_effective_number_polio_countries.png"
  ),
  plot_effective_countries,
  width = 10,
  height = 6,
  dpi = 300
)


# TOP COUNTRY SHARES



# 13. Prepare top-country concentration measures

top_share_data <- annual_concentration |>
  select(
    year,
    top_country_share,
    top_three_share,
    top_five_share
  ) |>
  pivot_longer(
    cols = c(
      top_country_share,
      top_three_share,
      top_five_share
    ),
    names_to = "measure",
    values_to = "share"
  ) |>
  mutate(
    
    measure =
      recode(
        measure,
        
        "top_country_share" =
          "Highest-burden country",
        
        "top_three_share" =
          "Three highest-burden countries",
        
        "top_five_share" =
          "Five highest-burden countries"
      )
  )


# 14. Plot burden concentration in leading countries

plot_top_shares <- top_share_data |>
  ggplot(
    aes(
      x = year,
      y = share,
      colour = measure
    )
  ) +
  geom_line(
    linewidth = 0.9
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
    title = "Share of estimated polio burden concentrated in leading countries",
    subtitle = "Annual share of estimated cases contributed by the highest-burden countries",
    x = "Year",
    y = "Share of estimated cases",
    colour = NULL
  ) +
  theme_minimal(
    base_size = 12
  ) +
  theme(
    legend.position = "bottom"
  )


plot_top_shares


ggsave(
  here(
    "plots",
    "12_polio_top_country_burden_shares.png"
  ),
  plot_top_shares,
  width = 11,
  height = 6,
  dpi = 300
)


# GLOBAL BURDEN VERSUS CONCENTRATION



# 15. Examine relationship between burden and concentration

burden_concentration_relationship <- annual_concentration |>
  filter(
    total_estimated_cases > 0
  ) |>
  summarise(
    
    spearman_rho =
      cor(
        log10(
          total_estimated_cases
        ),
        HHI,
        method = "spearman"
      )
  )


burden_concentration_relationship


# 16. Plot global burden against concentration

plot_burden_concentration <- annual_concentration |>
  filter(
    total_estimated_cases > 0
  ) |>
  ggplot(
    aes(
      x = total_estimated_cases,
      y = HHI
    )
  ) +
  geom_point(
    size = 2
  ) +
  scale_x_log10(
    labels = label_comma()
  ) +
  labs(
    title = "Global polio burden and geographic concentration",
    subtitle = "Exploratory relationship between annual estimated cases and HHI",
    x = "Estimated global cases (log scale)",
    y = "Herfindahl-Hirschman Index",
    caption = "Correlation is descriptive because annual observations form a longitudinal time series."
  ) +
  theme_minimal(
    base_size = 12
  )


plot_burden_concentration


ggsave(
  here(
    "plots",
    "13_global_burden_vs_concentration.png"
  ),
  plot_burden_concentration,
  width = 9,
  height = 6,
  dpi = 300
)


# SAVE OUTPUTS



write_csv(
  country_shares,
  here(
    "data",
    "processed",
    "polio_country_burden_shares.csv"
  )
)


write_csv(
  annual_concentration,
  here(
    "tables",
    "polio_annual_concentration.csv"
  )
)


write_csv(
  highest_concentration,
  here(
    "tables",
    "polio_highest_concentration_years.csv"
  )
)


write_csv(
  lowest_concentration,
  here(
    "tables",
    "polio_lowest_concentration_years.csv"
  )
)


write_csv(
  annual_top_country,
  here(
    "tables",
    "polio_annual_top_country.csv"
  )
)


write_csv(
  key_concentration_years,
  here(
    "tables",
    "polio_key_concentration_years.csv"
  )
)


write_csv(
  key_country_shares,
  here(
    "tables",
    "polio_key_country_shares.csv"
  )
)


write_csv(
  burden_concentration_relationship,
  here(
    "tables",
    "polio_burden_concentration_relationship.csv"
  )
)



message(
  "Polio geographic concentration analysis complete."
)