# current date
TODAY_DATE = $(shell date +'%Y-%m-%d')

sarix: cache-data fit-sarix-components combine-by-location build-sarix-ensemble plot-sarix

cache-data:
	Rscript --vanilla code/cache_data.R $(TODAY_DATE)

fit-sarix-components:
	python3 code/run_all_models_one_date_by_loc.py --forecast_date $(TODAY_DATE)

combine-by-location:
	Rscript --vanilla code/combine_forecasts_by_location.R $(TODAY_DATE)

build-sarix-ensemble:
	Rscript --vanilla code/build_sarix_ensemble.R $(TODAY_DATE)

plot-sarix:
	Rscript --vanilla code/plot_sarix_forecasts.R $(TODAY_DATE)
