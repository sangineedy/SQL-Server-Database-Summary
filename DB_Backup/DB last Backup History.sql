/********************************************************************************************
Author: L. S. N. Sandeep Kumar. Sangineedy
email: sandeepkumar4data@gmail.com
Purpose: Provide last Backup information (Full, Differential, Log, File Group, Differential_File, Partial, Differential File)
Compatible & Tested SQL Versions: 2005, 2008, 2008 R2, 2012, 2014, 2016, 2017, 2019 & 2022

Usage: 
1. Open SQL Server Management Studio (SSMS) and connect to SQL Server.
2. Select the specified database and create a “New Query”, copy the complete code and, paste it and run (Complete code).

Description: This script performs a detailed analysis of All backup (Full, Differential, Log, File Group, Differential_File, Partial, Differential File)
information.

Note: if DB backup is running on specific database, Backup percentage and estimate time to complete is mentioned instead

What does this script reads?

This Script reads below information from individual SQL Server Instance & databases level details and performs detailed analysis and displays result 

This Script reads below information from individual SQL Server Instance & databases level details and performs detailed analysis and displays result 

		************  SQL Instance Level  ************
		1.	[ sys.dm_exec_requests ]
		2.	[ master.sys.master_files ]
		3.	[ master.sys.databases ]
		4.	[ msdb.dbo.backupset ]


********************************************************************************************/
DECLARE @DB_Details TABLE (
  DBID int,
  DB_Name varchar(4000),
  [DB_Size] numeric(30, 2),
  create_date datetime,
  log_reuse_wait_desc varchar(200)
)
DECLARE @DB_Backup TABLE (
  [Database_Name] varchar(4000),
  [Recovery_Model] varchar(200),
  Full_backup datetime,
  Differential datetime,
  Log datetime,
  File_Filegroup datetime,
  Differential_file datetime,
  Partial datetime,
  Differential_partial datetime
)

DECLARE @Backup_happening_DB varchar(4000),
        @Backup_Status varchar(4000),
        @Backup_Command varchar(200)
SELECT
  @Backup_happening_DB = DB_NAME(Database_id),
  @Backup_Status = '[ <--- { ' + CAST(percent_complete AS varchar(30))
  + ' %, ' + CAST(DATEADD(MILLISECOND, estimated_completion_time, CURRENT_TIMESTAMP) AS varchar) + '} ---> ]',
  @Backup_Command = command
FROM sys.dm_exec_requests
WHERE command IN ('BACKUP DATABASE', 'BACKUP LOG')

INSERT INTO @DB_Details (DB_Name, [DB_Size])
  SELECT
    *
  FROM (SELECT
    [Database_Name],
    [DB_Size] = [DB_Size] * 8
  FROM (SELECT
    [Database_Name] = DB_NAME(database_id),
    [DB_Size] = CAST(SUM(size) AS numeric(30, 2))
  FROM master.sys.master_files
  WHERE DB_NAME(database_id) <> 'tempdb'
  GROUP BY DB_NAME(database_id)) A) db

UPDATE @DB_Details
SET DBID = database_id,
    create_date = db.create_date,
    log_reuse_wait_desc = db.log_reuse_wait_desc
FROM master.sys.databases db
WHERE db.name = [DB_Name]

INSERT INTO @DB_Backup ([Database_Name], [Recovery_Model], Full_backup, Differential, Log, File_Filegroup, Differential_file, Partial, Differential_partial)
  SELECT
    *
  FROM (SELECT
    [Database_Name] = database_name,
    [Recovery_Model] = CAST(DATABASEPROPERTYEX(database_name, 'Recovery') AS varchar),
    CASE
      WHEN type = 'D' THEN 'Full_backup'
      WHEN type = 'I' THEN 'Differential'
      WHEN type = 'L' THEN 'Log'
      WHEN type = 'F' THEN 'File_Filegroup'
      WHEN type = 'G' THEN 'Differential_file'
      WHEN type = 'P' THEN 'Partial'
      WHEN type = 'Q' THEN 'Differential_partial'
    END AS [Backup Type],
    MAX(backup_finish_date) AS [Last Backup of Type]
  FROM msdb.dbo.backupset
  WHERE database_name IN (SELECT
    name
  FROM master.sys.databases)
  GROUP BY database_name,
           DATABASEPROPERTYEX(database_name, 'Recovery'),
           type,
           database_name) AS S
  PIVOT
  (
  MAX([Last Backup of Type])
  FOR [Backup Type] IN (Full_backup, Differential, Log, File_Filegroup, Differential_file, Partial, Differential_partial)
  ) AS PVT

SELECT
  [Server Name] = SERVERPROPERTY('servername'),
  [dbid] = DB_Size.DBID,
  [Database Name] = DB_Size.DB_Name,
  [Recovery Model] = DATABASEPROPERTYEX(DB_Size.DB_Name, 'Recovery'),
  DB_Size.log_reuse_wait_desc,
  [DB_Size] =
             CASE
               WHEN DB_Size.[DB_Size] < 1024 THEN CAST((DB_Size.[DB_Size]) AS varchar(10)) + ' KB'
               WHEN DB_Size.[DB_Size] < 1048576 THEN CAST(CAST((DB_Size.[DB_Size]) / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
               WHEN DB_Size.[DB_Size] < 1073741824 THEN CAST(CAST((DB_Size.[DB_Size]) / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
               ELSE CAST(CAST((DB_Size.[DB_Size]) / 1073741824 AS numeric(10, 3)) AS varchar(20)) + ' TB'
             END,
  [Full backup (Days)] =
                        CASE
                          WHEN ((DB_Size.DB_Name = @Backup_happening_DB) AND
                            (@Backup_Command = 'BACKUP DATABASE')) THEN @Backup_Status
                          WHEN DB_Size.create_date > DB_Backup.[Full_backup] THEN '[ <-------- No DB Backup --------> ]'
                          ELSE ISNULL(CONVERT(varchar, Full_backup) + '   (' + CONVERT(varchar, DATEDIFF(DD, Full_backup, GETDATE())) + ' Day[s])', '[ <-------- No DB Backup --------> ]')
                        END,
  [Differential (Days)] = ISNULL(CONVERT(varchar, Differential) + '   (' + CONVERT(varchar, DATEDIFF(DD, Differential, GETDATE())) + ' Day[s])', ''),
  [Log Backup (Days)] =
                       CASE
                         WHEN [Recovery_Model] = 'SIMPLE' THEN '[Not Applicable]'
                         WHEN (DB_Size.DB_Name = @Backup_happening_DB) AND
                           (@Backup_Command = 'BACKUP LOG') THEN @Backup_Status
                         WHEN DB_Backup.[Database_Name] = 'model' AND
                           CONVERT(varchar, Log) IS NULL THEN '[Can be ignroed]'
                         ELSE ISNULL(CONVERT(varchar, Log) + '   (' + CONVERT(varchar, DATEDIFF(DD, Log, GETDATE())) + ' Day[s])', '[ <-------- No Transaction Log Backup --------> ]')
                       END,
  [File Filegroup (Days)] = ISNULL(CONVERT(varchar, File_Filegroup) + '   (' + CONVERT(varchar, DATEDIFF(DD, File_Filegroup, GETDATE())) + ' Day[s])', ''),
  [Differential file (Days)] = ISNULL(CONVERT(varchar, Differential_file) + '   (' + CONVERT(varchar, DATEDIFF(DD, Differential_file, GETDATE())) + ' Day[s])', ''),
  [Partial (Days)] = ISNULL(CONVERT(varchar, Partial) + '   (' + CONVERT(varchar, DATEDIFF(DD, Partial, GETDATE())) + ' Day[s])', ''),
  [Differential partial (Days)] = ISNULL(CONVERT(varchar, Differential_partial) + '   (' + CONVERT(varchar, DATEDIFF(DD, Differential_partial, GETDATE())) + ' Day[s])', '')

FROM @DB_Details DB_Size
LEFT JOIN @DB_Backup DB_Backup
  ON DB_Size.DB_Name = DB_Backup.[Database_Name]
ORDER BY DB_Size.DBID

GO
