# Movie BI — TMDB 5000 Data Warehouse

Đồ án môn Business Intelligence: xây dựng pipeline ETL chuyển bộ dữ liệu **TMDB 5000 Movies** thành mô hình **star schema** trên SQL Server (`MovieBI.dw`) để phục vụ phân tích / báo cáo BI.

## 1. Thành phần của project

```
business_intelligence/
├── code.ipynb              # Notebook ETL: đọc CSV gốc, sinh ra các bảng star-schema
├── sqlserver_dw_load.sql   # Script T-SQL: tạo DB MovieBI và BULK INSERT các CSV đã xử lý
├── movie 5000.zip          # Bản nén dự phòng của thư mục movie 5000/
├── movie 5000/
│   ├── tmdb_5000_movies.csv     # Dữ liệu thô: thông tin phim
│   ├── tmdb_5000_credits.csv    # Dữ liệu thô: cast & crew (hiện chưa dùng)
│   └── processed/               # Đầu ra của notebook → đầu vào cho SQL
│       ├── DimDate.csv
│       ├── DimGenre.csv
│       ├── DimMovieInfo.csv
│       ├── FactMovies.csv
│       └── BridgeMovieGenre.csv
├── CLAUDE.md               # Hướng dẫn cho Claude Code khi làm việc trong repo
└── README.md
```

### Vai trò của hai file chính

| File | Ngôn ngữ | Vai trò |
|------|----------|---------|
| [code.ipynb](code.ipynb) | Python (pandas) | Đọc 2 file CSV gốc → làm sạch, parse JSON cột `genres` → xuất 5 file CSV theo mô hình star schema |
| [sqlserver_dw_load.sql](sqlserver_dw_load.sql) | T-SQL | Tạo database `MovieBI`, schema `dw`, các bảng Dim/Fact/Bridge và `BULK INSERT` 5 CSV vào |

## 2. Mô hình Star Schema

Dữ liệu đích gồm 5 bảng trong schema `dw`:

- **DimDate** — chiều thời gian (release date), khóa `DateKey` dạng `YYYYMMDD`.
- **DimGenre** — chiều thể loại phim (id/name lấy từ TMDB).
- **DimMovieInfo** — chiều thông tin phim (Title, OriginalLanguage, Status), khóa `MovieKey` chính là `id` của TMDB.
- **FactMovies** — bảng fact với các chỉ số: `Budget`, `Revenue`, `VoteAverage`, `VoteCount`, `Popularity`, `Runtime`, `Profit (= Revenue − Budget)`. Giá trị `Budget`/`Revenue` bằng `0` trong TMDB là dấu hiệu "thiếu dữ liệu" (không phải $0 thật) → notebook chuyển thành **NULL**, nên `Profit` chỉ có giá trị khi biết **cả** Budget lẫn Revenue. Nhờ vậy các phép `SUM`/`AVG` về tài chính không bị 0 làm lệch, trong khi vẫn giữ đủ mọi dòng phim cho việc đếm số phim và phân tích đánh giá.
- **BridgeMovieGenre** — bảng cầu nối quan hệ nhiều–nhiều giữa Movie và Genre.

Số dòng kỳ vọng sau khi load thành công:

| Bảng | Số dòng |
|------|---------|
| DimDate | ~3.280 |
| DimGenre | 20 |
| DimMovieInfo | ~4.803 |
| FactMovies | ~4.803 |
| BridgeMovieGenre | ~12.160 |

> Lưu ý: `FactMovies` luôn giữ đủ ~4.803 dòng, nhưng sau khi lọc `> 0` thì chỉ ~3.376 phim có `Revenue`, ~3.766 phim có `Budget`, và ~3.229 phim có đủ cả hai để tính `Profit` (các ô còn lại là NULL).

## 3. Yêu cầu môi trường

- **Python 3.9+** với các thư viện: `pandas`, `numpy`, `jupyter` (hoặc dùng VS Code với extension Jupyter).
- **SQL Server** (Express/Developer/Standard đều được) + **SSMS** (SQL Server Management Studio).
- Tài khoản SQL có quyền `CREATE DATABASE`.
- Service account của SQL Server phải có quyền **đọc** thư mục chứa các CSV `processed/` (vì `BULK INSERT` chạy dưới quyền của service, không phải user đăng nhập SSMS).

Cài thư viện Python:

```bash
pip install pandas numpy jupyter
```

## 4. Cách chạy

> ⚠️ **Quan trọng:** Cả notebook và file SQL đều đang **hard-code đường dẫn tuyệt đối** trỏ tới vị trí repo hiện tại trên máy tác giả: `E:\Giáo trình đại học\Năm 4\Kỳ 2\BI\business_intelligence\movie 5000\...`. Nếu repo của bạn nằm ở nơi khác, hãy sửa lại các đường dẫn này cho khớp với máy của mình trước khi chạy.

### Bước 1 — Giải nén dữ liệu (nếu cần)

Nếu thư mục `movie 5000/` chưa có sẵn, giải nén `movie 5000.zip` ra cùng cấp với `code.ipynb`.

### Bước 2 — Chạy notebook để sinh CSV star-schema

1. Mở `code.ipynb` bằng Jupyter hoặc VS Code:
   ```bash
   jupyter notebook code.ipynb
   ```
2. Sửa các đường dẫn `E:\Giáo trình đại học\...` trong notebook (cell đọc CSV và biến `output_dir`) cho đúng với máy bạn (nếu repo nằm ở vị trí khác).
3. Chạy lần lượt tất cả các cell (Run All).
4. Kết quả: 5 file CSV được ghi vào `movie 5000/processed/` với encoding `utf-8-sig`.

### Bước 3 — Tạo data warehouse trên SQL Server

1. Mở `sqlserver_dw_load.sql` trong **SSMS**.
2. Sửa biến `@BasePath` ở dòng 140 cho trỏ đúng vào thư mục `processed/` đã sinh ở Bước 2 (mặc định đang trỏ tới vị trí repo trên máy tác giả):
   ```sql
   DECLARE @BasePath NVARCHAR(4000) = N'E:\Giáo trình đại học\Năm 4\Kỳ 2\BI\business_intelligence\movie 5000\processed\';
   ```
3. Kết nối tới SQL Server instance bằng tài khoản có quyền tạo database.
4. Nhấn **Execute (F5)** để chạy toàn bộ script.

Script sẽ:
- Tạo database `MovieBI` (nếu chưa có) và schema `dw`.
- Drop & re-create toàn bộ các bảng (tức là **full reload**, không phải incremental).
- Load CSV vào các bảng tạm `#stg*` (kiểu VARCHAR để dung thứ giá trị null/sai định dạng).
- Dùng `TRY_CONVERT` để chuyển sang đúng kiểu dữ liệu khi đổ vào bảng đích.
- Load theo thứ tự: Dimensions → Fact → Bridge.

### Bước 4 — Kiểm tra kết quả

Cuối script có sẵn câu lệnh đếm số dòng từng bảng. Sau khi chạy xong bạn sẽ thấy bảng kết quả ở tab Results — đối chiếu với số liệu kỳ vọng ở mục **2. Mô hình Star Schema**.

Hoặc tự kiểm tra:

```sql
USE MovieBI;
SELECT TOP 10 * FROM dw.FactMovies ORDER BY Revenue DESC;
SELECT g.GenreName, COUNT(*) AS NumMovies
FROM dw.BridgeMovieGenre b
JOIN dw.DimGenre g ON g.GenreID = b.GenreID
GROUP BY g.GenreName
ORDER BY NumMovies DESC;
```

## 5. Một số lưu ý kỹ thuật

- Các cột `genres`, `keywords`, `production_companies`, `production_countries`, `spoken_languages` trong file gốc của TMDB là **chuỗi JSON-ish** — notebook parse bằng `ast.literal_eval` trước, fallback sang `json.loads`. Không nên đổi sang dùng thẳng `json.loads` vì cách quote của TMDB sẽ làm nó lỗi.
- File `tmdb_5000_credits.csv` hiện được đọc nhưng **chưa sử dụng** ở downstream. Nếu mở rộng warehouse với chiều `DimCast`/`DimCrew`, có thể dùng dataframe `data_credit` đã có sẵn.
- CSV được ghi với `encoding='utf-8-sig'`; `BULK INSERT` đọc với `CODEPAGE = '65001'` (UTF-8). Phải giữ đồng bộ hai bên.
- `Profit` được **tính ở Python** (`Revenue − Budget`), không tính ở SQL. Nếu chỉnh công thức, phải sửa trong notebook rồi chạy lại từ Bước 2.
- Trước khi tính `Profit`, notebook lọc `Budget`/`Revenue` `> 0` (các giá trị `0`/âm bị coi là thiếu dữ liệu → NaN → xuất ra rỗng → load thành NULL). Vì vậy: số đếm phim và phân tích rating vẫn dùng đủ ~4.803 dòng, nhưng biểu đồ doanh thu/lợi nhuận/ngân sách chỉ phản ánh các phim có số liệu thật. Muốn lấy lại giá trị `0` gốc thì bỏ dòng `fact_movies[col].where(fact_movies[col] > 0)` trong notebook và chạy lại.

## 6. Nguồn dữ liệu

Bộ dữ liệu **TMDB 5000 Movies Dataset** từ Kaggle:
<https://www.kaggle.com/datasets/tmdb/tmdb-movie-metadata>
