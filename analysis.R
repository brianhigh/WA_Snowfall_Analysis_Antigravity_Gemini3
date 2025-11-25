# WA Snowfall Analysis
# Relationship between ENSO (El Niño/La Niña) and Snowfall in WA Cascades

# 1. Setup and Package Loading --------------------------------------------
if (!require("pacman")) install.packages("pacman")
pacman::p_load(tidyverse, lubridate, janitor, ggthemes, rvest, readr)

# Create directories if they don't exist
dir.create("data", showWarnings = FALSE)
dir.create("plots", showWarnings = FALSE)

# 2. Data Acquisition -----------------------------------------------------

# --- 2a. SNOTEL Data (Snowfall) ---
# Sites: Stevens Pass (791), Olallie Meadows (672), Paradise (679), Wells Creek (909)
# We will construct URLs dynamically to fetch CSVs directly from NRCS Report Generator

snotel_sites <- tibble(
    site_id = c(791, 672, 679, 909),
    site_name = c("Stevens Pass", "Olallie Meadows (Snoqualmie)", "Paradise", "Wells Creek (Mt Baker)")
)

# Function to download SNOTEL data
download_snotel <- function(site_id, site_name) {
    # URL pattern for daily data: Snow Water Equivalent (WTEQ), Snow Depth (SNWD), Precipitation (PREC), Air Temp (TOBS)
    # Fetching last 40 years (approx 15000 days) to cover enough history
    url <- paste0(
        "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customSingleStationReport/daily/",
        site_id, ":WA:SNTL|id=%22%22|name/-15000,0/WTEQ::value,SNWD::value,PREC::value,TOBS::value"
    )

    dest_file <- file.path("data", paste0("snotel_", site_id, ".csv"))

    message(paste("Downloading data for", site_name, "..."))
    tryCatch(
        {
            download.file(url, dest_file, mode = "wb")
            return(dest_file)
        },
        error = function(e) {
            warning(paste("Failed to download", site_name, ":", e$message))
            return(NULL)
        }
    )
}

# Download data for all sites
snotel_files <- snotel_sites %>%
    mutate(file_path = map2_chr(site_id, site_name, download_snotel))

# --- 2b. ENSO Data (ONI) ---
# Source: NOAA PSL
oni_url <- "https://psl.noaa.gov/data/correlation/oni.data"
oni_file <- "data/oni.data"

message("Downloading ONI data...")
download.file(oni_url, oni_file, mode = "wb")




# 3. Data Cleaning and Processing -----------------------------------------

# --- 3a. Process SNOTEL Data ---
read_snotel <- function(file_path, site_name) {
    # Skip comment lines (usually start with #)
    d <- read_csv(file_path, comment = "#", show_col_types = FALSE) %>%
        clean_names() %>%
        rename(
            date = date,
            swe_in = snow_water_equivalent_in_start_of_day_values,
            snow_depth_in = snow_depth_in_start_of_day_values,
            precip_in = precipitation_accumulation_in_start_of_day_values,
            temp_f = air_temperature_observed_deg_f_start_of_day_values
        ) %>%
        mutate(date = as.Date(date))
    return(d)
}

snow_data <- snotel_files %>%
    mutate(data = map2(file_path, site_name, read_snotel)) %>%
    unnest(data) %>%
    select(site_name, date, snow_depth_in)

# Filter for Snow Season (Nov - Apr)
# We define a "Season Year" as the year the season ends (e.g., Nov 2020 - Apr 2021 is Season 2021)
snow_data <- snow_data %>%
    mutate(
        month = month(date),
        year = year(date),
        season_year = if_else(month >= 11, year + 1, year)
    ) %>%
    filter(month %in% c(11, 12, 1, 2, 3, 4)) %>%
    mutate(month_label = factor(month,
        levels = c(11, 12, 1, 2, 3, 4),
        labels = c("Nov", "Dec", "Jan", "Feb", "Mar", "Apr")
    ))

# Aggregate monthly max snow depth (or average, but max is often good for "snowfall" proxy if daily new snow isn't available.
# SNOTEL gives snow depth. Let's use Max Snow Depth per month as a proxy for "how snowy it was".)
# Alternatively, we could calculate daily differences to estimate "snowfall", but depth is more robust in raw SNOTEL data.
# Let's stick to "Snow Depth" as the metric, or "Max Snow Depth".
# User asked for "Snowfall". SNOTEL "Snow Depth" is the standing snow.
# Calculating daily new snow: (Depth_today - Depth_yesterday) if > 0.
# This is a common approximation. Let's try to calculate daily new snow.

snow_data_daily <- snow_data %>%
    group_by(site_name) %>%
    arrange(date) %>%
    mutate(
        prev_depth = lag(snow_depth_in, default = 0),
        daily_snowfall = pmax(0, snow_depth_in - prev_depth) # Only positive changes
    ) %>%
    ungroup()

# Monthly Total Snowfall (Approximate)
monthly_snow <- snow_data_daily %>%
    group_by(site_name, season_year, month_label) %>%
    summarise(total_snowfall = sum(daily_snowfall, na.rm = TRUE), .groups = "drop")


# --- 3b. Process ONI Data ---
# ONI data format is tricky: Year followed by 12 columns.
# We need to parse it carefully.
oni_lines <- read_lines(oni_file)

# Filter for lines that look like data (Year at start)
oni_lines_clean <- oni_lines[str_detect(oni_lines, "^\\s*(19|20)\\d{2}")]

# Read the cleaned lines
oni_clean <- read_table(I(oni_lines_clean), col_names = c("year", paste0("month_", 1:12)), show_col_types = FALSE) %>%
    pivot_longer(cols = starts_with("month_"), names_to = "month_idx", values_to = "oni") %>%
    mutate(
        year = as.integer(year),
        month = as.integer(str_remove(month_idx, "month_")),
        oni = as.numeric(oni) # Ensure numeric, -99.90 should be handled
    ) %>%
    filter(oni > -90) %>% # Filter out missing values (-99.90)
    select(year, month, oni)

# Define ONI for the Snow Season
# We need to classify each "Season Year".
# Standard definition: ONI is a 3-month running mean.
# Let's use the average ONI during the core winter months (e.g., Nov-Mar) to classify the season.
# Or better, use the official "Year" classification.
# Usually, ENSO years are defined by the ONI values in the OND, NDJ, DJF, JFM, FMA seasons.
# Let's average ONI from Nov (prev year) to Mar (current season year).

oni_season <- oni_clean %>%
    mutate(
        season_year = if_else(month >= 11, year + 1, year)
    ) %>%
    filter(month %in% c(11, 12, 1, 2, 3)) %>% # Core winter
    group_by(season_year) %>%
    summarise(avg_oni = mean(oni, na.rm = TRUE), .groups = "drop")

# Classify Seasons
# Thresholds:
# Strong La Niña: <= -1.5
# Weak La Niña: -1.5 < x <= -0.5
# Neutral: -0.5 < x < 0.5
# Weak El Niño: 0.5 <= x < 1.5
# Strong El Niño: >= 1.5

oni_classified <- oni_season %>%
    mutate(
        enso_phase = case_when(
            avg_oni <= -1.5 ~ "Strong La Niña",
            avg_oni > -1.5 & avg_oni <= -0.5 ~ "Weak La Niña",
            avg_oni > -0.5 & avg_oni < 0.5 ~ "Neutral",
            avg_oni >= 0.5 & avg_oni < 1.5 ~ "Weak El Niño",
            avg_oni >= 1.5 ~ "Strong El Niño"
        ),
        enso_phase = factor(enso_phase, levels = c(
            "Strong La Niña", "Weak La Niña", "Neutral", "Weak El Niño", "Strong El Niño"
        ))
    )

# 4. Merge Data -----------------------------------------------------------

final_data <- monthly_snow %>%
    inner_join(oni_classified, by = "season_year")

# 5. Analysis and Plotting ------------------------------------------------

# Define Colors
enso_colors <- c(
    "Strong La Niña" = "blue",
    "Weak La Niña" = "lightblue",
    "Neutral" = "#D8BFD8", # Light purple (Thistle)
    "Weak El Niño" = "lightcoral", # Light red
    "Strong El Niño" = "red"
)

# Year Range for Titles
year_range <- paste(min(final_data$season_year), max(final_data$season_year), sep = "-")
data_source_caption <- "Data Sources: USDA NRCS (SNOTEL), NOAA PSL (ONI)"

# --- Plot 1: Monthly Snowfall by ENSO Phase ---
# Compare El Niño vs La Niña (Grouped)
# We'll group Strong/Weak together for a simpler first plot, or just show all phases.
# User asked: "comparing snowfall during El Niño and La Niña years... by site and month"
# Let's show the average monthly snowfall for each phase.

plot1_data <- final_data %>%
    group_by(site_name, month_label, enso_phase) %>%
    summarise(avg_snowfall = mean(total_snowfall, na.rm = TRUE), .groups = "drop")

p1 <- ggplot(plot1_data, aes(x = month_label, y = avg_snowfall, fill = enso_phase, group = enso_phase)) +
    geom_col(position = "dodge") +
    facet_wrap(~site_name, scales = "free_y") +
    scale_fill_manual(values = enso_colors) +
    labs(
        title = paste("Average Monthly Snowfall by ENSO Phase (", year_range, ")", sep = ""),
        subtitle = "WA Cascade Sites",
        x = "Month",
        y = "Average Total Snowfall (inches)",
        fill = "ENSO Phase",
        caption = data_source_caption
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("plots/snowfall_by_enso_month.png", p1, width = 12, height = 8)


# --- Plot 2: Percentage Difference (Strong vs Weak) ---
# "Compare snowfall in strong vs weak intensities... show percentage snowfall difference by site"
# We need a baseline. Let's use "Neutral" or the overall average as baseline?
# Or maybe compare Strong vs Weak directly?
# "Percentage snowfall difference" usually implies (Value - Baseline) / Baseline.
# Let's calculate the average annual snowfall for each phase, then calculate % diff from Neutral.
# If Neutral is missing or 0, we might have issues.
# Let's calculate % difference relative to the "Neutral" phase for each site.

site_neutral_avg <- final_data %>%
    filter(enso_phase == "Neutral") %>%
    group_by(site_name) %>%
    summarise(neutral_avg = mean(total_snowfall, na.rm = TRUE), .groups = "drop")

plot2_data <- final_data %>%
    group_by(site_name, enso_phase) %>%
    summarise(phase_avg = mean(total_snowfall, na.rm = TRUE), .groups = "drop") %>%
    left_join(site_neutral_avg, by = "site_name") %>%
    mutate(
        pct_diff = (phase_avg - neutral_avg) / neutral_avg * 100
    ) %>%
    filter(enso_phase != "Neutral") # Remove Neutral from the plot as it's the baseline (0%)

p2 <- ggplot(plot2_data, aes(x = site_name, y = pct_diff, fill = enso_phase)) +
    geom_col(position = "dodge") +
    scale_fill_manual(values = enso_colors) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray") +
    labs(
        title = paste("Snowfall % Difference from Neutral Years (", year_range, ")", sep = ""),
        subtitle = "Strong vs Weak ENSO Intensities",
        x = "Site",
        y = "Percentage Difference (%)",
        fill = "ENSO Phase",
        caption = data_source_caption
    ) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("plots/snowfall_pct_diff_strong_weak.png", p2, width = 10, height = 6)

message("Analysis complete. Plots saved to 'plots/' directory.")
