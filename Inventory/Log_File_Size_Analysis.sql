/******************************************************************************************** 
Author: L. S. N. Sandeep Kumar.Sangineedy
email: sangineedy@gmail.com
Purpose: Analyze SQL DB Log file(s), Virtual Log files & Size information for all online SQL Databases
Compatible & Tested SQL Versions: 2005, 2008, 2008 R2, 2012, 2014 & 2016 
 
Usage:  
1. Open SQL Server Management Studio (SSMS) and connect to SQL Server. 
2. Click on “New Query”, copy the complete code and, paste it and run (Complete code). 
 
Description: This Script reads SQL Server databases LOG files information from below mentioned DBCC commands and displays in friendly way
 
	1. [ DBCC LOGINFO ]
	2. [ DBCC SQLPERF(LOGSPACE) ]
	3. [ sys.databases ]

********************************************************************************************/ 
 

DECLARE @DBCC_SQLPERF TABLE(
Dbid INT,
Database_Name VARCHAR(4000),
Recovery VARCHAR(500),
Log_Reuse_Wait VARCHAR(200),
Number_of_Log_Files INT,
Virtual_Log_Files INT,
Log_Total_Size_MB NUMERIC(30,3),
Log_Used_Size_MB NUMERIC(30,3),
Log_Used_Percent NUMERIC(30,3),
Log_Free_Size_MB NUMERIC(30,3),
Log_Free_Percent NUMERIC(30,3),
Status INT
)

IF OBJECT_ID('tempdb..##VLFInfo') IS NOT NULL
	DROP TABLE ##VLFInfo

IF OBJECT_ID('tempdb..##VLFCountResults') IS NOT NULL
	DROP TABLE ##VLFCountResults

CREATE TABLE ##VLFInfo(
RecoveryUnitID int, 
FileID  int,
FileSize bigint, 
StartOffset bigint,
FSeqNo bigint, 
[Status] bigint,
Parity bigint, 
CreateLSN numeric(38));

IF (PARSENAME(CONVERT(varchar(32), CAST(SERVERPROPERTY('ProductVersion') AS varchar(50))), 4) <= 10 )
    ALTER TABLE ##VLFInfo DROP COLUMN RecoveryUnitID
		 
CREATE TABLE ##VLFCountResults(DatabaseName sysname, VLFCount int); 
EXEC sp_MSforeachdb N'Use [?]; 
				INSERT INTO ##VLFInfo EXEC sp_executesql N''DBCC LOGINFO([?])''; 	 
				INSERT INTO ##VLFCountResults SELECT DB_NAME(), COUNT(*) FROM ##VLFInfo; 
				TRUNCATE TABLE ##VLFInfo;'

INSERT INTO @DBCC_SQLPERF(Database_Name,Log_Total_Size_MB,Log_Used_Percent,Status)
EXEC('DBCC SQLPERF(LOGSPACE)')

UPDATE @DBCC_SQLPERF 
	SET Recovery = recovery_model_desc,
		Log_Reuse_Wait = log_reuse_wait_desc 
		FROM master.sys.databases
		WHERE Database_Name = name

UPDATE @DBCC_SQLPERF 
SET Dbid = DB_ID(Database_Name)
	,Log_Used_Size_MB = (Log_Total_Size_MB/100)*Log_Used_Percent

UPDATE @DBCC_SQLPERF 
	SET Log_Free_Size_MB = Log_Total_Size_MB - Log_Used_Size_MB,
		Log_Free_Percent = 100 - Log_Used_Percent

UPDATE @DBCC_SQLPERF SET Number_of_Log_Files = 
( SELECT filescount FROM
(SELECT Dbname = DB_NAME(database_id),filescount = COUNT(*) FROM sys.master_files where type = 1
GROUP BY DB_NAME(database_id)) A  
WHERE Dbname = Database_Name)

UPDATE @DBCC_SQLPERF SET Virtual_Log_Files =
(SELECT VLFCount FROM ##VLFCountResults WHERE DatabaseName = Database_Name )

SELECT	[SQL Instance Name] = SERVERPROPERTY('servername')
		,Dbid
		,Database_Name
		,Recovery
		,Log_Reuse_Wait
		,Number_of_Log_Files
		,Virtual_Log_Files
		,[Log File Size] = CASE WHEN (Log_Total_Size_MB)< 1024 then CAST(CAST(((Log_Total_Size_MB)) AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
			WHEN (Log_Total_Size_MB)< 1048576 then CAST(CAST(((Log_Total_Size_MB))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
			WHEN (Log_Total_Size_MB)< 1073741824  then CAST(CAST(((Log_Total_Size_MB))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' 
			ELSE CAST(CAST(((Log_Total_Size_MB))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' PB' END
		,[Used Log File Size (%)] = CASE WHEN (Log_Used_Size_MB)< 1024 then CAST(CAST(((Log_Used_Size_MB)) AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
			WHEN (Log_Used_Size_MB)< 1048576 then CAST(CAST(((Log_Used_Size_MB))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
			WHEN (Log_Used_Size_MB)< 1073741824  then CAST(CAST(((Log_Used_Size_MB))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' 
			ELSE CAST(CAST(((Log_Used_Size_MB))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' PB' END + ' ( '+ CAST(Log_Used_Percent AS VARCHAR(100)) + ' % )'
		,[Free Log File Size (%) ] = CASE WHEN (Log_Free_Size_MB)< 1024 then CAST(CAST(((Log_Free_Size_MB)) AS NUMERIC(10,3))AS VARCHAR(20)) +' MB' 
			WHEN (Log_Free_Size_MB)< 1048576 then CAST(CAST(((Log_Free_Size_MB))/1024.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' GB' 
			WHEN (Log_Free_Size_MB)< 1073741824  then CAST(CAST(((Log_Free_Size_MB))/1048576.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' TB' 
			ELSE CAST(CAST(((Log_Free_Size_MB))/1073741824.0 AS NUMERIC(10,3))AS VARCHAR(20)) +' PB' END + ' ( '+ CAST(Log_Free_Percent AS VARCHAR(100)) + ' % )'
		 FROM @DBCC_SQLPERF
		 ORDER BY Log_Total_Size_MB DESC

DROP TABLE ##VLFInfo;
DROP TABLE ##VLFCountResults;


GO

