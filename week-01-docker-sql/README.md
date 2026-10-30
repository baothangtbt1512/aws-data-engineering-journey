# 🚖 Week 1: Environment Setup, Docker Containerization & Advanced SQL

> **Dự án thuộc lộ trình:** Data Engineering Zoomcamp & Chinh phục AWS Certified Data Engineer - Associate (DEA-C01).

---

## 🎯 Mục tiêu bài học (Learning Objectives)

1. **Containerization (Docker & Docker Compose):**
   - Đóng gói PostgreSQL và pgAdmin thành các container độc lập.
   - Thiết lập Bridge Network (`taxi-network`) để các container giao tiếp qua hostname nội bộ.
   - Khởi tạo Named Volumes (`pgdata`, `pgadmin-data`) để bảo toàn dữ liệu ngay cả khi container bị hủy (`docker compose down`).
2. **Batch Data Ingestion Pipeline:**
   - Xây dựng Python Ingestion Pipeline xử lý file dữ liệu lớn (NYC Taxi Parquet/CSV).
   - Áp dụng kỹ thuật **Batch Streaming / Chunking** với `pyarrow.parquet.ParquetFile.iter_batches()` và `pandas.read_csv(chunksize=...)` nhằm loại bỏ rủi ro tràn RAM (Out of Memory - OOM).
   - Đóng gói toàn bộ script thành 1 Docker image với CLI arguments linh hoạt.
3. **Advanced SQL & Database Performance:**
   - Sử dụng Window Functions (`LEAD`, `LAG`, `DENSE_RANK()`).
   - Phân tích và đánh giá hiệu năng truy vấn bằng `EXPLAIN ANALYZE`.
   - Thiết lập chiến lược đánh chỉ mục B-Tree Index để tối ưu tốc độ đọc bảng lớn.
4. **Liên hệ kỳ thi AWS Certified Data Engineer (DEA-C01):**
   - Phân biệt kiến trúc **OLTP** (Amazon RDS PostgreSQL, Amazon Aurora) và **OLAP** (Amazon Redshift, Amazon Athena).

---

## 🏗️ Kiến trúc hệ thống (Architecture)

```
[ NYC TLC Public Dataset ]
           │
           ▼ (HTTP Stream Download)
 ┌──────────────────────────────────────┐
 │ Container: data_ingestion_pipeline   │
 │ (Python 3.11, PyArrow, SQLAlchemy)   │
 └──────────────────┬───────────────────┘
                    │ (Batch Insert / Port 5432)
                    ▼
 ┌──────────────────────────────────────┐     ┌──────────────────────────────────┐
 │ Container: postgres_db               │◄────┤ Container: pgadmin_ui            │
 │ (PostgreSQL 15 - Volume: pgdata)     │     │ (pgAdmin 4 - Web UI Port: 8080)  │
 └──────────────────────────────────────┘     └──────────────────────────────────┘
       ▲                                                     ▲
       └─────────────────── taxi-network ────────────────────┘
```

---

## 🚀 Hướng dẫn thực hành từng bước (Step-by-Step Guide)

### Bước 1: Khởi động PostgreSQL & pgAdmin

Từ thư mục `week-01-docker-sql/`, chạy lệnh:

```bash
docker compose up -d postgres pgadmin
```

Kiểm tra trạng thái các container đang hoạt động:

```bash
docker compose ps
```

---

### Bước 2: Kết nối pgAdmin với PostgreSQL

1. Mở trình duyệt và truy cập: [http://localhost:8080](http://localhost:8080)
2. Đăng nhập với tài khoản:
   - **Email:** `admin@admin.com`
   - **Password:** `root`
3. Đăng ký kết nối Database mới (**Register > Server**):
   - **Tab General > Name:** `Local NYC Taxi DB`
   - **Tab Connection:**
     - **Host name/address:** `postgres` *(Lưu ý: dùng tên service trong Docker network, không dùng localhost)*
     - **Port:** `5432`
     - **Maintenance database:** `ny_taxi`
     - **Username:** `root`
     - **Password:** `root`
4. Bấm **Save**.

---

### Bước 3: Chạy Data Ingestion Pipeline

Bạn có 2 cách để nạp dữ liệu:

#### Cách 1: Chạy trực tiếp qua Docker Compose (Khuyên dùng)
```bash
docker compose --profile ingest up --build
```
Lệnh này sẽ tự động tải file Parquet NYC Taxi (tháng 01/2023 ~3 triệu dòng), chia thành các batch 100,000 dòng và nạp thẳng vào bảng `yellow_taxi_trips`.

#### Cách 2: Chạy trực tiếp qua Python trên máy Host (nếu có môi trường Python)
```bash
pip install -r requirements.txt

python pipeline.py \
  --user=root \
  --password=root \
  --host=localhost \
  --port=5432 \
  --db=ny_taxi \
  --table_name=yellow_taxi_trips \
  --url=https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2023-01.parquet \
  --batch_size=100000
```

---

### Bước 4: Thực thi các câu truy vấn SQL chuyên sâu

Mở Query Tool trong pgAdmin và chạy các kịch bản trong thư mục `queries/`:

#### 1. Đánh chỉ mục Indexing & Tối ưu hóa truy vấn (`queries/schema_and_indexes.sql`)
* **Mục tiêu:** Đo lường thời gian truy vấn trước và sau khi đánh B-Tree Index trên cột `tpep_pickup_datetime` và `"PULocationID"`.
* **Kết quả quan sát:**
  * **Trước Index:** PostgreSQL thực hiện `Seq Scan` (quét tuần tự toàn bộ hàng triệu dòng).
  * **Sau Index:** PostgreSQL chuyển sang `Bitmap Index Scan` / `Index Scan`, giảm thời gian thực thi đáng kể.

#### 2. Tính khoảng cách giữa các chuyến đón liên tiếp bằng `LAG()` (`queries/query_1_window_lead_lag.sql`)
* **Mục tiêu:** Tính số phút xe taxi đón lượt khách kế tiếp tại Sân bay JFK (`PULocationID = 132`) để phân tích độ trễ phân bổ xe.

#### 3. Tìm Top 3 địa điểm đón khách doanh thu cao nhất mỗi ngày bằng `DENSE_RANK()` (`queries/query_2_top_pickup_dense_rank.sql`)
* **Mục tiêu:** Sử dụng `PARTITION BY trip_date ORDER BY total_revenue DESC` để phân nhóm và xếp hạng cục bộ theo từng ngày.

#### 4. Phân tích doanh thu & Tỷ lệ tiền Tip theo khung giờ (`queries/query_3_advanced_aggregates.sql`)
* **Mục tiêu:** Phân loại khung giờ (Rush Hour, Late Night, Daytime) và phương thức thanh toán (Credit Card vs Cash) bằng `CASE WHEN`, đồng thời tính phần trăm tiền tip chính xác.

---

## ☁️ Góc nhìn chuẩn bị cho kỳ thi AWS Certified Data Engineer (DEA-C01)

| Khái niệm thực hành hôm nay | Dịch vụ tương đương trên AWS | Điểm cốt lõi cần nhớ cho bài thi DEA-C01 |
| :--- | :--- | :--- |
| **PostgreSQL Container** | **Amazon RDS for PostgreSQL** / **Amazon Aurora PostgreSQL** | RDS phù hợp với bài toán **OLTP** (Online Transaction Processing) có ACID transactions, truy vấn theo Primary Key / Index. Không tối ưu cho việc quét hàng tỷ dòng để aggregate. |
| **Volume Persistence** | **Amazon EBS (Elastic Block Store)** | Ổ đĩa gắn vào EC2/RDS. Cần chọn loại ổ đĩa (gp3, io2) phù hợp với IOPS yêu cầu của workload dữ liệu. |
| **Docker Compose Ingestion** | **AWS Lambda** / **AWS Glue Python Shell** | Xử lý nạp dữ liệu định kỳ theo batch nhỏ. Với các file dữ liệu lớn vượt quá 15 phút timeout của Lambda, ưu tiên chuyển sang **AWS Glue** hoặc container trên **Amazon ECS/Fargate**. |
| **Indexing vs Partitioning** | **B-Tree Index (RDS)** vs **Partition Key (S3/Athena/Redshift)** | Trong RDBMS dùng B-Tree Index. Trong Datalake/DWH (Athena/Redshift), ta dùng **Partitioning** (chia thư mục S3 theo ngày/tháng) và **Sort Keys** để loại bỏ partition pruning. |

---

## 📌 Hướng dẫn Commit & Push lên GitHub Portfolio

Sau khi hoàn thành thực hành, thực hiện các lệnh sau để lưu trữ làm minh chứng tự học:

```bash
git add week-01-docker-sql/
git commit -m "feat(week-01): complete dockerized ingestion pipeline and advanced SQL queries"
git push origin main
```
