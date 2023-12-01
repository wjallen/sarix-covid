library(dplyr)
library(lubridate)
library(readr)
library(covidData)

args <- commandArgs(trailingOnly = TRUE)

# The forecast_date is the date of forecast creation.
forecast_date <- args[1]

required_locations <-
  readr::read_csv(file = "./data/locations.csv") %>%
  dplyr::select("location", "abbreviation")

# Load data (by dropping the last observation)
hosp_data <- covidData::load_data(
  spatial_resolution = c("national", "state"),
  temporal_resolution = "daily",
  measure = "hospitalizations",
  drop_last_date = FALSE
  ) %>%
  dplyr::filter(location != "60") %>%
  dplyr::left_join(covidData::fips_codes, by = "location") %>%
  dplyr::transmute(
    date,
    location,
    location_name = ifelse(location_name == "United States", "US", location_name),
    value = inc) %>%
  dplyr::arrange(location, date)


data <- hosp_data %>%
    dplyr::filter(date >= "2020-10-01") %>%
    dplyr::rename(hosps = value)


location_info <- readr::read_csv('data/locations.csv')
data <- data %>%
    dplyr::left_join(location_info %>% dplyr::transmute(location, pop100k = population / 100000)) %>%
    dplyr::mutate(hosp_rate = hosps / pop100k)

readr::write_csv(data, paste0('data/jhu_data_cached_', forecast_date, '.csv'))
