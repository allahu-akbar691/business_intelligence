/*
    Movie BI Warehouse - SQL Server setup and CSV load script
    Source CSV folder (exported by Python notebook):
    D:\for school\business intel\movie 5000\processed\

    Run in SSMS with an account that has permission to create database/tables.
    Ensure SQL Server service account can read the CSV folder.
*/

SET NOCOUNT ON;
GO

IF DB_ID(N'MovieBI') IS NULL
BEGIN
    CREATE DATABASE MovieBI;
END
GO

USE MovieBI;
GO

IF SCHEMA_ID(N'dw') IS NULL
BEGIN
    EXEC('CREATE SCHEMA dw');
END
GO

/* Drop old objects in dependency-safe order */
IF OBJECT_ID(N'dw.BridgeMovieGenre', N'U') IS NOT NULL DROP TABLE dw.BridgeMovieGenre;
IF OBJECT_ID(N'dw.FactMovies', N'U') IS NOT NULL DROP TABLE dw.FactMovies;
IF OBJECT_ID(N'dw.DimGenre', N'U') IS NOT NULL DROP TABLE dw.DimGenre;
IF OBJECT_ID(N'dw.DimDate', N'U') IS NOT NULL DROP TABLE dw.DimDate;
IF OBJECT_ID(N'dw.DimMovieInfo', N'U') IS NOT NULL DROP TABLE dw.DimMovieInfo;
GO

/* Create dimension and fact tables */
CREATE TABLE dw.DimDate
(
    DateKey     INT           NOT NULL PRIMARY KEY,
    FullDate    DATE          NOT NULL,
    [Year]      SMALLINT      NOT NULL,
    [Quarter]   TINYINT       NOT NULL,
    [Month]     TINYINT       NOT NULL,
    MonthName   NVARCHAR(20)  NOT NULL
);
GO

CREATE TABLE dw.DimGenre
(
    GenreID     INT            NOT NULL PRIMARY KEY,
    GenreName   NVARCHAR(100)  NOT NULL
);
GO

CREATE TABLE dw.DimMovieInfo
(
    MovieKey           INT             NOT NULL PRIMARY KEY,
    Title              NVARCHAR(400)   NOT NULL,
    OriginalLanguage   NVARCHAR(20)    NULL,
    [Status]           NVARCHAR(50)    NULL
);
GO

CREATE TABLE dw.FactMovies
(
    MovieKey      INT             NOT NULL PRIMARY KEY,
    DateKey       INT             NULL,
    Budget        BIGINT          NULL,
    Revenue       BIGINT          NULL,
    VoteAverage   DECIMAL(5,2)    NULL,
    VoteCount     INT             NULL,
    Popularity    DECIMAL(18,6)   NULL,
    Runtime       DECIMAL(6,2)    NULL,
    Profit        BIGINT          NULL,
    CONSTRAINT FK_FactMovies_DimMovieInfo FOREIGN KEY (MovieKey) REFERENCES dw.DimMovieInfo(MovieKey),
    CONSTRAINT FK_FactMovies_DimDate FOREIGN KEY (DateKey) REFERENCES dw.DimDate(DateKey)
);
GO

CREATE TABLE dw.BridgeMovieGenre
(
    MovieKey   INT NOT NULL,
    GenreID    INT NOT NULL,
    CONSTRAINT PK_BridgeMovieGenre PRIMARY KEY (MovieKey, GenreID),
    CONSTRAINT FK_BridgeMovieGenre_DimMovieInfo FOREIGN KEY (MovieKey) REFERENCES dw.DimMovieInfo(MovieKey),
    CONSTRAINT FK_BridgeMovieGenre_DimGenre FOREIGN KEY (GenreID) REFERENCES dw.DimGenre(GenreID)
);
GO

/* Staging tables (VARCHAR/NVARCHAR) to safely parse null/invalid values */
IF OBJECT_ID('tempdb..#stgDimDate') IS NOT NULL DROP TABLE #stgDimDate;
IF OBJECT_ID('tempdb..#stgDimGenre') IS NOT NULL DROP TABLE #stgDimGenre;
IF OBJECT_ID('tempdb..#stgDimMovieInfo') IS NOT NULL DROP TABLE #stgDimMovieInfo;
IF OBJECT_ID('tempdb..#stgFactMovies') IS NOT NULL DROP TABLE #stgFactMovies;
IF OBJECT_ID('tempdb..#stgBridgeMovieGenre') IS NOT NULL DROP TABLE #stgBridgeMovieGenre;

CREATE TABLE #stgDimDate
(
    DateKey    VARCHAR(20)      NULL,
    FullDate   VARCHAR(20)      NULL,
    [Year]     VARCHAR(10)      NULL,
    [Quarter]  VARCHAR(10)      NULL,
    [Month]    VARCHAR(10)      NULL,
    MonthName  NVARCHAR(50)     NULL
);

CREATE TABLE #stgDimGenre
(
    GenreID    VARCHAR(20)      NULL,
    GenreName  NVARCHAR(100)    NULL
);

CREATE TABLE #stgDimMovieInfo
(
    MovieKey           VARCHAR(20)     NULL,
    Title              NVARCHAR(400)   NULL,
    OriginalLanguage   NVARCHAR(20)    NULL,
    [Status]           NVARCHAR(50)    NULL
);

CREATE TABLE #stgFactMovies
(
    MovieKey     VARCHAR(20)     NULL,
    DateKey      VARCHAR(20)     NULL,
    Budget       VARCHAR(30)     NULL,
    Revenue      VARCHAR(30)     NULL,
    VoteAverage  VARCHAR(30)     NULL,
    VoteCount    VARCHAR(30)     NULL,
    Popularity   VARCHAR(30)     NULL,
    Runtime      VARCHAR(30)     NULL,
    Profit       VARCHAR(30)     NULL
);

CREATE TABLE #stgBridgeMovieGenre
(
    MovieKey   VARCHAR(20)     NULL,
    GenreID    VARCHAR(20)     NULL
);

DECLARE @BasePath NVARCHAR(4000) = N'D:\for school\business intel\movie 5000\processed\';
DECLARE @SQL NVARCHAR(MAX);

/* BULK INSERT helper settings for UTF-8 CSV with header */
SET @SQL = N'BULK INSERT #stgDimDate FROM ''' + REPLACE(@BasePath + N'DimDate.csv', '''', '''''') + N'''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @SQL;

SET @SQL = N'BULK INSERT #stgDimGenre FROM ''' + REPLACE(@BasePath + N'DimGenre.csv', '''', '''''') + N'''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @SQL;

SET @SQL = N'BULK INSERT #stgDimMovieInfo FROM ''' + REPLACE(@BasePath + N'DimMovieInfo.csv', '''', '''''') + N'''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @SQL;

SET @SQL = N'BULK INSERT #stgFactMovies FROM ''' + REPLACE(@BasePath + N'FactMovies.csv', '''', '''''') + N'''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @SQL;

SET @SQL = N'BULK INSERT #stgBridgeMovieGenre FROM ''' + REPLACE(@BasePath + N'BridgeMovieGenre.csv', '''', '''''') + N'''
WITH (
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';
EXEC sp_executesql @SQL;

/* Load dimensions first */
INSERT INTO dw.DimDate (DateKey, FullDate, [Year], [Quarter], [Month], MonthName)
SELECT
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(DateKey)), '')),
    TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(FullDate)), '')),
    TRY_CONVERT(SMALLINT, NULLIF(LTRIM(RTRIM([Year])), '')),
    TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM([Quarter])), '')),
    TRY_CONVERT(TINYINT, NULLIF(LTRIM(RTRIM([Month])), '')),
    COALESCE(NULLIF(LTRIM(RTRIM(MonthName)), ''), N'Unknown')
FROM #stgDimDate
WHERE TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(DateKey)), '')) IS NOT NULL;

INSERT INTO dw.DimGenre (GenreID, GenreName)
SELECT
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(GenreID)), '')),
    COALESCE(NULLIF(LTRIM(RTRIM(GenreName)), ''), N'Unknown')
FROM #stgDimGenre
WHERE TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(GenreID)), '')) IS NOT NULL;

INSERT INTO dw.DimMovieInfo (MovieKey, Title, OriginalLanguage, [Status])
SELECT
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(MovieKey)), '')),
    COALESCE(NULLIF(LTRIM(RTRIM(Title)), ''), N'Unknown Title'),
    NULLIF(LTRIM(RTRIM(OriginalLanguage)), ''),
    NULLIF(LTRIM(RTRIM([Status])), '')
FROM #stgDimMovieInfo
WHERE TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(MovieKey)), '')) IS NOT NULL;

/* Load fact after dimensions */
INSERT INTO dw.FactMovies
(
    MovieKey,
    DateKey,
    Budget,
    Revenue,
    VoteAverage,
    VoteCount,
    Popularity,
    Runtime,
    Profit
)
SELECT
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(MovieKey)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(DateKey)), '')),
    TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(Budget)), '')),
    TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(Revenue)), '')),
    TRY_CONVERT(DECIMAL(5,2), NULLIF(LTRIM(RTRIM(VoteAverage)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(VoteCount)), '')),
    TRY_CONVERT(DECIMAL(18,6), NULLIF(LTRIM(RTRIM(Popularity)), '')),
    TRY_CONVERT(DECIMAL(6,2), NULLIF(LTRIM(RTRIM(Runtime)), '')),
    TRY_CONVERT(BIGINT, NULLIF(LTRIM(RTRIM(Profit)), ''))
FROM #stgFactMovies
WHERE TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(MovieKey)), '')) IS NOT NULL;

/* Load many-to-many bridge */
INSERT INTO dw.BridgeMovieGenre (MovieKey, GenreID)
SELECT
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(MovieKey)), '')),
    TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(GenreID)), ''))
FROM #stgBridgeMovieGenre
WHERE TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(MovieKey)), '')) IS NOT NULL
  AND TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(GenreID)), '')) IS NOT NULL;

/* Quick load summary */
SELECT 'dw.DimDate' AS TableName, COUNT(1) AS [RowCount] FROM dw.DimDate
UNION ALL SELECT 'dw.DimGenre', COUNT(1) FROM dw.DimGenre
UNION ALL SELECT 'dw.DimMovieInfo', COUNT(1) FROM dw.DimMovieInfo
UNION ALL SELECT 'dw.FactMovies', COUNT(1) FROM dw.FactMovies
UNION ALL SELECT 'dw.BridgeMovieGenre', COUNT(1) FROM dw.BridgeMovieGenre;
GO
