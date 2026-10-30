#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Data Ingestion Pipeline for NYC Taxi Dataset into PostgreSQL
Week 1 - AWS Data Engineering Zoomcamp Journey
"""

import os
import sys
import time
import argparse
import logging
from urllib.parse import urlparse
import requests
import pandas as pd
import pyarrow.parquet as pq
from sqlalchemy import create_engine, text
from tqdm import tqdm

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)


def download_file(url: str, output_path: str):
    """Download file from URL with streaming progress."""
    if os.path.exists(output_path):
        logging.info(f"File already exists at '{output_path}', skipping download.")
        return

    logging.info(f"Downloading from '{url}' to '{output_path}'...")
    response = requests.get(url, stream=True, timeout=60)
    response.raise_for_status()

    total_size = int(response.headers.get("content-length", 0))
    block_size = 1024 * 1024  # 1MB chunk

    with open(output_path, "wb") as f, tqdm(
        total=total_size, unit="iB", unit_scale=True, desc="Downloading"
    ) as progress_bar:
        for chunk in response.iter_content(chunk_size=block_size):
            if chunk:
                f.write(chunk)
                progress_bar.update(len(chunk))
    logging.info("Download completed successfully.")


def ingest_parquet(file_path: str, engine, table_name: str, batch_size: int = 100_000):
    """Ingest Parquet data in batches to avoid OOM memory spikes."""
    logging.info(f"Opening Parquet file: {file_path}")
    parquet_file = pq.ParquetFile(file_path)
    total_rows = parquet_file.metadata.num_rows
    logging.info(f"Total rows in dataset: {total_rows:,} rows.")

    is_first_batch = True
    processed_rows = 0
    start_time = time.time()

    with tqdm(total=total_rows, unit="rows", desc="Ingesting Parquet") as pbar:
        for batch in parquet_file.iter_batches(batch_size=batch_size):
            batch_df = batch.to_pandas()

            # Ensure proper datetime casting if present
            datetime_cols = [col for col in batch_df.columns if "datetime" in col.lower()]
            for col in datetime_cols:
                batch_df[col] = pd.to_datetime(batch_df[col])

            # Calculate safe chunksize for PostgreSQL protocol limit (max 65,535 parameters)
            num_cols = len(batch_df.columns)
            safe_chunksize = max(1, 65_000 // num_cols)
            # Cap at 2000 rows per multi-insert statement to remain well within protocol limit
            safe_chunksize = min(safe_chunksize, 2_000)

            mode = "replace" if is_first_batch else "append"
            batch_df.to_sql(
                name=table_name,
                con=engine,
                if_exists=mode,
                index=False,
                chunksize=safe_chunksize,
                method="multi",
            )

            is_first_batch = False
            batch_len = len(batch_df)
            processed_rows += batch_len
            pbar.update(batch_len)

    elapsed_time = time.time() - start_time
    logging.info(
        f"Ingestion finished! Loaded {processed_rows:,} rows in {elapsed_time:.2f}s "
        f"({processed_rows / elapsed_time:.0f} rows/sec)."
    )


def ingest_csv(file_path: str, engine, table_name: str, batch_size: int = 100_000):
    """Ingest CSV/CSV.GZ data in chunks."""
    logging.info(f"Opening CSV file with chunk size {batch_size:,}: {file_path}")
    df_iter = pd.read_csv(file_path, iterator=True, chunksize=batch_size, low_memory=False)

    is_first_batch = True
    processed_rows = 0
    start_time = time.time()

    for chunk in df_iter:
        # Cast datetime columns
        datetime_cols = [col for col in chunk.columns if "datetime" in col.lower()]
        for col in datetime_cols:
            chunk[col] = pd.to_datetime(chunk[col])

        num_cols = len(chunk.columns)
        safe_chunksize = min(max(1, 65_000 // num_cols), 2_000)

        mode = "replace" if is_first_batch else "append"
        chunk.to_sql(
            name=table_name,
            con=engine,
            if_exists=mode,
            index=False,
            chunksize=safe_chunksize,
            method="multi",
        )

        is_first_batch = False
        processed_rows += len(chunk)
        logging.info(f"Inserted batch of {len(chunk):,} rows (Total: {processed_rows:,} rows)")

    elapsed_time = time.time() - start_time
    logging.info(f"CSV Ingestion finished! Total: {processed_rows:,} rows in {elapsed_time:.2f}s.")


def main():
    parser = argparse.ArgumentParser(description="Ingest NYC Taxi data into PostgreSQL database")
    parser.add_argument("--user", required=False, default="root", help="Database username")
    parser.add_argument("--password", required=False, default="root", help="Database password")
    parser.add_argument("--host", required=False, default="localhost", help="Database host")
    parser.add_argument("--port", required=False, default="5432", help="Database port")
    parser.add_argument("--db", required=False, default="ny_taxi", help="Database name")
    parser.add_argument("--table_name", required=False, default="yellow_taxi_trips", help="Target table name")
    parser.add_argument(
        "--url",
        required=False,
        default="https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet",
        help="Source data URL",
    )
    parser.add_argument("--batch_size", type=int, default=100_000, help="Batch chunk size for processing")

    args = parser.parse_args()

    # Determine local file name from URL path
    parsed_url = urlparse(args.url)
    file_name = os.path.basename(parsed_url.path)
    if not file_name:
        file_name = "dataset.parquet" if args.url.endswith(".parquet") else "dataset.csv"

    os.makedirs("data", exist_ok=True)
    local_file_path = os.path.join("data", file_name)

    # 1. Download data
    download_file(args.url, local_file_path)

    # 2. Connect to PostgreSQL
    connection_url = f"postgresql://{args.user}:{args.password}@{args.host}:{args.port}/{args.db}"
    logging.info(f"Connecting to database at {args.host}:{args.port}/{args.db}...")
    engine = create_engine(connection_url)

    # Test database connectivity
    with engine.connect() as conn:
        result = conn.execute(text("SELECT version();")).fetchone()
        logging.info(f"Connected successfully to PostgreSQL! Version: {result[0]}")

    # 3. Batch Ingestion
    if local_file_path.endswith(".parquet"):
        ingest_parquet(local_file_path, engine, args.table_name, batch_size=args.batch_size)
    else:
        ingest_csv(local_file_path, engine, args.table_name, batch_size=args.batch_size)

    # 4. Summary verification
    with engine.connect() as conn:
        count = conn.execute(text(f"SELECT COUNT(*) FROM {args.table_name};")).scalar()
        logging.info(f"Verification: Table '{args.table_name}' currently contains {count:,} records.")


if __name__ == "__main__":
    main()
