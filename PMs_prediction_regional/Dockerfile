FROM rocker/geospatial:4.4.3

LABEL org.opencontainers.image.title="APEMAIA PM10/PM2.5 inference"
LABEL org.opencontainers.image.description="Inference-only XGBoost container for daily 300 m PM10 and PM2.5 prediction over Puglia, with Bari maps"
LABEL org.opencontainers.image.source="https://github.com/APEMAIAproject/src"
LABEL org.opencontainers.image.version="5.1.0"

# The supplied XGBoost models use the legacy binary model format.
# Pin XGBoost to the tested 1.7.x release that can load them.
RUN install2.r --error --skipinstalled \
      data.table \
      jsonlite \
      ggplot2 \
      viridis \
    && R -q -e 'install.packages("https://cran.r-project.org/src/contrib/Archive/xgboost/xgboost_1.7.11.1.tar.gz", repos = NULL, type = "source")' \
    && R -q -e 'stopifnot(as.character(packageVersion("xgboost")) == "1.7.11.1")'

WORKDIR /app

COPY model_prediction_docker.R /app/model_prediction_docker.R
COPY models/xg.pm10 /opt/pms/models/xg.pm10
COPY models/xg.pm2.5 /opt/pms/models/xg.pm2.5
COPY spatial/grid_puglia_minimal.gpkg.zip /tmp/grid_puglia_minimal.gpkg.zip
COPY spatial/grid_bari_minimal.gpkg.zip /tmp/grid_bari_minimal.gpkg.zip

# The source repository stores the reference grids compressed to keep Git small.
# Expand them once while building the image; runtime users do not need the grids.
RUN mkdir -p /opt/pms/spatial \
    && Rscript -e 'utils::unzip("/tmp/grid_puglia_minimal.gpkg.zip", exdir="/opt/pms/spatial"); utils::unzip("/tmp/grid_bari_minimal.gpkg.zip", exdir="/opt/pms/spatial")' \
    && test -s /opt/pms/spatial/grid_puglia_minimal.gpkg \
    && test -s /opt/pms/spatial/grid_bari_minimal.gpkg \
    && rm -f /tmp/grid_puglia_minimal.gpkg.zip /tmp/grid_bari_minimal.gpkg.zip

ENV MODEL_DIR=/opt/pms/models \
    SPATIAL_DIR=/opt/pms/spatial \
    OUTPUT_DIR=/output \
    INPUT_PATH=/input/input.csv

ENTRYPOINT ["Rscript", "/app/model_prediction_docker.R"]
