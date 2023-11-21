import sys
sys.path.insert(0, '.')

from multiprocessing import Pool

import argparse

import os
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import norm

from datetime import date

import itertools

from sarix import sarix


def expand_grid(data_dict):
  """Create a dataframe from every combination of given values."""
  rows = itertools.product(*data_dict.values())
  return pd.DataFrame.from_records(rows, columns=data_dict.keys())


def load_data(as_of = '2022-04-18'):
  """
  Load data for cases from CDC and for hosps from healthdata.gov

  Parameters
  ----------
  as_of: string of date in YYYY-MM-DD format. Default to '2022-04-18'
  
  Returns
  -------
  df: data frame
    It has columns location, date, inc_hosp, population and rate.
    It is sorted by location and date columns in ascending order.
  """
  # load hospitalizations
  hosp_df = pd.read_csv(f'data/jhu_data_cached_{as_of}.csv')
  hosp_df = hosp_df[['location', 'date', 'pop100k', 'hosp_rate']]
  hosp_df['hosp_rate_sqrt'] = hosp_df['hosp_rate'] ** 0.5
  hosp_df['hosp_rate_fourthrt'] = hosp_df['hosp_rate'] ** 0.25
  
  df = hosp_df
  
  # ensure correct data types
  df.date = pd.to_datetime(df.date)
  float_vars = ['hosp_rate', 'hosp_rate_sqrt', 'hosp_rate_fourthrt']
  df[float_vars] = df[float_vars].astype('float64')
  
  return df


def construct_forecast_df(location, forecast_date, pred_qs, q_levels, base_target):
  # format predictions for one target variable as a data frame with required columns
  horizons_str = [str(i + 1) for i in range(28)]
  preds_df = pd.DataFrame(pred_qs, columns = horizons_str)
  preds_df['forecast_date'] = forecast_date
  preds_df['location'] = location
  preds_df['quantile'] = q_levels
  preds_df = pd.melt(preds_df,
            id_vars=['forecast_date', 'location', 'quantile'],
            var_name='horizon')
  preds_df['target_end_date'] = pd.to_datetime(preds_df['forecast_date']).values + \
    pd.to_timedelta(preds_df['horizon'].astype(int), 'days')
  preds_df['base_target'] = base_target
  preds_df['target'] = preds_df['horizon'] + preds_df['base_target']
  preds_df['type'] = 'quantile'
  preds_df = preds_df[['location', 'forecast_date', 'target', 'target_end_date', 'type', 'quantile', 'value']]
  return preds_df


def save_forecast_files(location, forecast_date, hosp_pred_qs, q_levels, model_name): #(location, forecast_date, hosp_pred_qs, case_pred_qs, q_levels, model_name):
  pred_df = construct_forecast_df(location,
                                 forecast_date,
                                 hosp_pred_qs,
                                 q_levels,
                                 ' day ahead inc hosp')
  
  # save predictions
  model_dir = Path("weekly-submission/sarix-forecasts/hosps-by-loc/") / model_name
  model_dir.mkdir(mode=0o775, parents=True, exist_ok=True)
  file_path = model_dir / f"{forecast_date}-{model_name}-{location}.csv"
  pred_df.to_csv(file_path, index = False)
  

def build_model_name(covariates, smooth_covariates, transform, p, d, P, D, pooling):
  return f"SARIX_covariates_{covariates}_" + \
    f"smooth_{smooth_covariates}_" + \
    f"transform_{transform}_" + \
    f"p_{p}_" + \
    f"d_{d}_" + \
    f"P_{P}_" + \
    f"D_{D}_" + \
    f"pooling_{pooling}"


def fit_sarix_variation(covariates, smooth_covariates, transform, p, d, P, D, pooling, location, forecast_date):
    if covariates == 'none':
        modeled_vars = ['hosp_rate']
    # load data
    data = load_data(forecast_date)
    state_info = pd.read_csv('data/locations.csv')
    
    # quantile levels at which to generate predictions
    q_levels = np.array([0.01, 0.025, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35,
                         0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70, 0.75, 0.80,
                         0.85, 0.90, 0.95, 0.975, 0.99])
    
    loc_data = data[data.location == location]
    state_pop100k = (state_info[state_info.location == location]['population'] / 100000.).values[0]
    
    # figure out horizons
    # last date with observed data
    last_obs_date = pd.to_datetime(loc_data.iloc[-1].date)
    # how far out to forecast to get to 28 days after due date
    due_date = pd.to_datetime(forecast_date)
    extra_horizons_rel_obs = (due_date - last_obs_date).days
    effective_horizon_rel_obs = 28 + extra_horizons_rel_obs
    
    sarix_fit = sarix.SARIX(
        xy = loc_data[modeled_vars].dropna().values,
        p = p,
        d = d,
        P = P,
        D = D,
        season_period = 7,
        transform = transform,
        forecast_horizon = effective_horizon_rel_obs,
        num_warmup = 1000,
        num_samples = 1000,
        num_chains = 1)
    
    pred_samples = sarix_fit.predictions
    
    # extract predictive quantiles for response variable
    hosp_pred_qs = np.percentile(pred_samples[:, :, -1], q_levels * 100.0, axis = 0)
    
    # subset to those we want to keep
    hosp_pred_qs = hosp_pred_qs[:, extra_horizons_rel_obs:]
    
    # get back to counts scale rather than rate per 100k population
    hosp_pred_qs = hosp_pred_qs * state_pop100k
    
    model_name = build_model_name(covariates, smooth_covariates, transform, p, d, P, D, pooling)
    save_forecast_files(location=location,
                        forecast_date=forecast_date,
                        hosp_pred_qs=hosp_pred_qs,
                        # case_pred_qs=case_pred_qs,
                        q_levels=q_levels,
                        model_name=model_name)


if __name__ == "__main__":
    # parse arguments
    parser = argparse.ArgumentParser(description="hierarchicalGP")
    parser.add_argument("--forecast_date", nargs="?", default='2022-04-18', type = str)
    args = parser.parse_args()
    forecast_date = args.forecast_date

    # define model variations to fit
    data = load_data(forecast_date)
    sarix_variations =  expand_grid({
        'covariates': ['none'],
        'smooth_covariates': [False],
        'transform': ['fourthrt'],
        'p': [14, 28, 42, 56],
        'd': [0],
        'P': [0],
        'D': [0],
        'pooling': ['none'],
        'location': data.location.unique(),
        'forecast_date': [forecast_date]
    })

    # keep only variations with some kind of lag
    sarix_variations = sarix_variations[(sarix_variations.p != 0) | (sarix_variations.P != 0)]

    # drop variations with covariates == 'none' and smooth_covariates == True
    sarix_variations = sarix_variations[~((sarix_variations.covariates == 'none') & (sarix_variations.smooth_covariates))]

    # keep only variations without a model fit file
    model_names = [build_model_name(sarix_variations['covariates'].values[i],
                                    sarix_variations['smooth_covariates'].values[i],
                                    sarix_variations['transform'].values[i],
                                    sarix_variations['p'].values[i],
                                    sarix_variations['d'].values[i],
                                    sarix_variations['P'].values[i],
                                    sarix_variations['D'].values[i],
                                    sarix_variations['pooling'].values[i]) \
                    for i in range(sarix_variations.shape[0])]
    file_paths = [
        Path("weekly-submission/sarix-forecasts/hosps-by-loc/") / model_name / f"{forecast_date}-{model_name}-{sarix_variations['location'].values[i]}.csv" \
            for i, model_name in enumerate(model_names)]
    file_doesnt_exist = [not file_path.exists() for file_path in file_paths]
    sarix_variations = sarix_variations.loc[file_doesnt_exist]
  
    # only proceed if there are models to fit
    if sarix_variations.shape[0] > 0:
        # fit models
        with Pool(processes=7) as pool:
            pool.starmap(fit_sarix_variation,
                         sarix_variations.to_records(index=False))
