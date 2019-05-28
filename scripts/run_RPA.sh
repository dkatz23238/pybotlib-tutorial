#! /bin/bash
export MINIO_URL=minio;
export MINIO_ACCESS_KEY=123456;
export MINIO_SECRET_KEY=password;
export MINIO_OUTPUT_BUCKET_NAME=financials;
export GSHEET_ID=1pBecz5Db9eK0QDR_oePmamdaFtEiCaO69RaE-Ozduko;
export DISPLAY=:1;

# Pip will only use the current users directory
python3.7 -m pip install --user robot --no-cache-dir pybotlib

python3.7 run_RPA.py