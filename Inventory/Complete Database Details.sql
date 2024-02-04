/*******************************************************************************************
Author: L.S.N. Sandeep Kumar. Sangineedy
email: sandeepkumar4data@gmail.com
Purpose: Provide Individual SQL Server database information
Compatible & Tested SQL Versions: 2005, 2008, 2008 R2, 2012, 2016, 2017, 2019 & 2022

Usage: 
1. Open SQL Server Management Studio (SSMS) and connect to SQL Server.
2. Select the specified database and create a “New Query”, copy the complete code and, paste it and run (Complete code).

In case if you have so many file groups, you can filter with specific filegroup by passing specific file group name to this 

SELECT @File_Group_Filter = '%'


Description: This script performs a detailed analysis of current DB status and provided 8 results as explained below

Result 1: Gives High level information about SQL Server database
Result 2 & 3: Detailed Analyzes of overall DB size, utilization & free space in very detailed method 
Result 4: number of DB Data files( DB Filegroups), DB Log Files (Virtual Log Files)
  		Last DB Backup, DB Differential Backup & Transaction Log BACKUP
			Note: If Full, Differential (or) Transaction log backup is running on specific databases [Backup% and [Estimated time to complete]]
Result 5: Individual filegroup wise DB Size Analysis with number of file count in each filegroup
Result 6: Detailed information of individual DB file like 
			Logical, Physical files details, Size(Total, Used, Free & Free%), File growth & filegroup
Result 7: DB Properties like (Autoclose, Autocreatestats, Autoshrink, AutoUpdatestats)
Result 8: DB Replication Details (If this DB is involved in DB Replication as Publisher, Subscriber)
Result 9: DB Properties like (Fulltext enabled, standby, Perameterization force, Tornpagedetection, In-Memory Supported)

What does this script reads?

This Script reads below information from individual SQL Server Instance & databases level details and performs detailed analysis and displays result 

		/************  SQL Instance Level  ************/
		1.	[ sys.databases ]
		2.	[ SERVERPROPERTY ]
		3.	[ msdb.dbo.backupset ]
		4.	[ sys.dm_exec_requests ]
		5.  [ sys.dm_exec_sql_text ]
		
		/************  Database Level  ************/
		6.	[ sysfiles ]
		7.	[ filegroups ]
		8.  [ DATABASEPROPERTYEX ]
		9.  [ DBCC LOGINFO() ]
		
*******************************************************************************************/

BEGIN TRY

  DECLARE @File_Group_Filter varchar(500)

  SELECT
    @File_Group_Filter = '%' /* <-- Enter Your Filegroup name to filter*/


  DECLARE @DB_Data_Files_Count int,
          @DB_Log_Files_Count int,
          @SQL_Command varchar(4000),
          @Product_Version varchar(50),
          @DB_Recovery_Model varchar(100),
          @DB_Created_Date datetime


  /*************************************** sys.databases **************************************************/

  DECLARE @Sysdatabases TABLE (
    database_id int,
    Database_Name varchar(4000),
    DB_Owner varchar(4000),
    DB_Created_Date datetime,
    DB_Compatibility int,
    page_verify_desc varchar(500),
    log_reuse_wait varchar(2000)
  )

  INSERT INTO @Sysdatabases (database_id, Database_Name, DB_Owner, DB_Created_Date, DB_Compatibility, page_verify_desc, log_reuse_wait)
    SELECT
      database_id,
      name,
      SUSER_SNAME(owner_sid),
      create_date,
      compatibility_level,
      page_verify_option_desc,
      log_reuse_wait_desc
    FROM master.sys.databases
    WHERE name = DB_NAME()


  /*************************************** sysfiles & filegroups **************************************************/


  DECLARE @Complete_DB_Size numeric(30, 2),
          @Used_Size numeric(30, 2),
          @Free_Size numeric(30, 2),
          @Data_Size numeric(30, 3),
          @Log_Size numeric(30, 2),
          @DB_Files_Count int,
          @Log_Files_Count int,
          @Virtual_Log_Files_Count int,
          @Full_Backup datetime,
          @Full_Backup_Summary varchar(2000),
          @Differential_Backup datetime,
          @Differential_Backup_Summary varchar(2000),
          @Log_Backup datetime,
          @Log_Backup_Summary varchar(2000),
          @Data_Used_Size numeric(30, 3),
          @Log_Used_Size numeric(30, 3),
          @Data_Free_Size numeric(30, 3),
          @Log_Free_Size numeric(30, 3)

  DECLARE @Sysfiles TABLE (
    groupid int,
    size_kb numeric(30, 0),
    used_size_kb numeric(30, 0),
    free_size_kb numeric(30, 2),
    maxsize_mb numeric(30, 0),
    growth int,
    Filetype varchar(20),
    name varchar(4000),
    filename varchar(4000),
    filegroup varchar(4000)
  )
  DECLARE @filegroup TABLE (
    File_group_id int,
    File_Group_name varchar(4000),
    Is_Default int
  )

  SELECT
    @Product_Version = CAST(SERVERPROPERTY('ProductVersion') AS varchar),
    @DB_Recovery_Model = CAST(DATABASEPROPERTYEX(DB_NAME(), 'Recovery') AS varchar(100))
  SELECT
    @DB_Created_Date = DB_Created_Date
  FROM @Sysdatabases

  INSERT INTO @Sysfiles (groupid, size_kb, maxsize_mb, growth, Filetype, name, filename)
    SELECT
      groupid,
      size,
      maxsize,
      growth,
      CASE
        WHEN (status & 0x40) > 0 THEN 'Log'
        WHEN (status & 0x2) > 0 THEN 'Data'
        ELSE 'Unknown'
      END,
      name,
      filename
    FROM sysfiles
  INSERT INTO @filegroup (File_group_id, File_Group_name, Is_Default)
    SELECT
      data_space_id,
      name,
      is_default
    FROM.sys.filegroups


  UPDATE @Sysfiles
  SET filegroup = (SELECT
    [File Group] =
                  CASE
                    WHEN is_default = 1 THEN File_Group_name + ' (Default)'
                    ELSE File_Group_name
                  END
  FROM @filegroup
  WHERE groupid = File_group_id)
  UPDATE @Sysfiles
  SET filegroup = 'DB Transaction Log File'
  WHERE filegroup IS NULL
  DECLARE @Total_DB_Files int,
          @File_group_Count int

  SELECT
    @Total_DB_Files = COUNT(*)
  FROM @Sysfiles
  SELECT
    @File_group_Count = COUNT(File_group_id)
  FROM @filegroup
  UPDATE @Sysfiles
  SET size_kb = size_kb * 8,
      used_size_kb = FILEPROPERTY(name, 'spaceused') * 8,
      free_size_kb = (size_kb - FILEPROPERTY(name, 'spaceused')) * 8,
      maxsize_mb = maxsize_mb * 8 / 1024

  SELECT
    @Complete_DB_Size = SUM(size_kb),
    @Used_Size = SUM(used_size_kb),
    @Free_Size = SUM(free_size_kb)
  FROM @Sysfiles

  SELECT
    @Data_Size = SUM(size_kb),
    @Data_Used_Size = SUM(used_size_kb),
    @Data_Free_Size = SUM(free_size_kb),
    @DB_Files_Count = COUNT(*)
  FROM @Sysfiles
  WHERE Filetype = 'Data'
  SELECT
    @Log_Size = SUM(size_kb),
    @Log_Used_Size = SUM(used_size_kb),
    @Log_Free_Size = SUM(free_size_kb),
    @Log_Files_Count = COUNT(*)
  FROM @Sysfiles
  WHERE Filetype = 'Log'

  IF EXISTS (SELECT
      *
    FROM tempdb..sysobjects
    WHERE name LIKE '##VLFInfo')
    DROP TABLE ##VLFInfo
  CREATE TABLE ##VLFInfo (
    RecoveryUnitID int,
    FileID int,
    FileSize bigint,
    StartOffset bigint,
    FSeqNo bigint,
    [Status] bigint,
    Parity bigint,
    CreateLSN numeric(38)
  );

  IF (@@VERSION LIKE '%9.0%')
    ALTER TABLE ##VLFInfo DROP COLUMN RecoveryUnitID

  INSERT INTO ##VLFInfo
  EXEC sp_executesql N'DBCC LOGINFO()'

  SELECT
    @Virtual_Log_Files_Count = COUNT(*)
  FROM ##VLFInfo

  DROP TABLE ##VLFInfo
  SELECT
    @Full_Backup = MAX([Full Backup]),
    @Differential_Backup = MAX([Differential Backup]),
    @Log_Backup = MAX([Log Backup])
  FROM (SELECT
    [Full Backup] =
                   CASE
                     WHEN type = 'D' THEN MAX(backup_finish_date)
                   END,
    [Differential Backup] =
                           CASE
                             WHEN type = 'I' THEN MAX(backup_finish_date)
                           END,
    [Log Backup] =
                  CASE
                    WHEN type = 'L' THEN MAX(backup_finish_date)
                  END
  FROM msdb.dbo.backupset
  WHERE database_name = DB_NAME()
  GROUP BY database_name,
           type) A


  SELECT
    @Full_Backup_Summary = NULL,
    @Differential_Backup_Summary = NULL,
    @Log_Backup_Summary = NULL

  SELECT
    @Differential_Backup_Summary =
    CAST(CAST(r.percent_complete AS numeric(30, 3)) AS varchar(50)) + '% [' +
    CAST(DATEADD(MILLISECOND, r.estimated_completion_time, CURRENT_TIMESTAMP) AS varchar(100)) + ']'
  FROM sys.dm_exec_requests r
  CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a
  WHERE r.command IN ('BACKUP DATABASE')
  AND DB_NAME(Database_id) = DB_NAME()
  AND a.text LIKE '%DIFFERENTIAL%'

  IF (@Differential_Backup_Summary IS NOT NULL
    AND LEN(@Differential_Backup_Summary) > 2)
    SELECT
      @Differential_Backup_Summary = @Differential_Backup_Summary
  ELSE
    SELECT
      @Differential_Backup_Summary =
                                    CASE
                                      WHEN @Differential_Backup IS NULL THEN 'No Differential Backup'
                                      ELSE CAST(@Differential_Backup AS varchar(50)) + ' (' + CAST(DATEDIFF(D, @Differential_Backup, GETDATE()) AS varchar(50)) + ' days)'
                                    END



  SELECT
    @Full_Backup_Summary =
    CAST(CAST(r.percent_complete AS numeric(30, 3)) AS varchar(50)) + '% [' +
    CAST(DATEADD(MILLISECOND, r.estimated_completion_time, CURRENT_TIMESTAMP) AS varchar(100)) + ']'
  FROM sys.dm_exec_requests r
  CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a
  WHERE r.command IN ('BACKUP DATABASE')
  AND DB_NAME(Database_id) = DB_NAME()
  AND a.text NOT LIKE '%DIFFERENTIAL%'

  IF (@Full_Backup_Summary IS NOT NULL
    AND LEN(@Full_Backup_Summary) > 2)
    SELECT
      @Full_Backup_Summary = @Full_Backup_Summary
  ELSE
    SELECT
      @Full_Backup_Summary =
                            CASE
                              WHEN @Full_Backup < @DB_Created_Date THEN 'No DB Backup'
                              WHEN @Full_Backup IS NULL THEN 'No DB Backup'
                              ELSE CAST(@Full_Backup AS varchar(50)) + ' (' + CAST(DATEDIFF(D, @Full_Backup, GETDATE()) AS varchar(50)) + ' days)'
                            END



  SELECT
    @Log_Backup_Summary =
    CAST(CAST(percent_complete AS numeric(30, 3)) AS varchar(50)) + '% [' +
    CAST(DATEADD(MILLISECOND, estimated_completion_time, CURRENT_TIMESTAMP) AS varchar(100)) + ']'
  FROM sys.dm_exec_requests
  WHERE command IN ('BACKUP LOG')
  AND DB_NAME(Database_id) = DB_NAME()

  IF (@Log_Backup_Summary IS NOT NULL
    AND LEN(@Log_Backup_Summary) > 2)
    SELECT
      @Log_Backup_Summary = @Log_Backup_Summary
  ELSE
    SELECT
      @Log_Backup_Summary =
                           CASE
                             WHEN @DB_Recovery_Model LIKE 'SIMPLE' THEN '---NA---'
                             WHEN @Log_Backup IS NULL THEN 'No Transaction Log Backup'
                             ELSE CAST(@Log_Backup AS varchar(50)) + ' (' + CAST(DATEDIFF(HH, @Log_Backup, GETDATE()) AS varchar(50)) + ' Hours)'
                           END


  /*************************************** Result **************************************************/

  -- SQL Database high level part 1
  SELECT
    'SQL Instance name [Version]' = CAST(SERVERPROPERTY('servername') AS varchar(2000)) +
    CASE
      WHEN @Product_Version LIKE N'8%' THEN ' [SQL 2000]'
      WHEN @Product_Version LIKE N'9%' THEN ' [SQL 2005]'
      WHEN @Product_Version LIKE N'10%' THEN ' [SQL 2008]'
      WHEN @Product_Version LIKE N'11%' THEN ' [SQL 2012]'
      WHEN @Product_Version LIKE N'12%' THEN ' [SQL 2014]'
      WHEN @Product_Version LIKE N'13%' THEN ' [SQL 2016]'
      WHEN @Product_Version LIKE N'14%' THEN ' [SQL 2017]'
      WHEN @Product_Version LIKE N'15%' THEN ' [SQL 2019]'
      WHEN @Product_Version LIKE N'16%' THEN ' [SQL 2022]'
    END,
    [Database Name] = DB_NAME(),
    [Created Date] = CAST(@DB_Created_Date AS varchar(50)),
    [Recovery] = @DB_Recovery_Model,
    [Status] = DATABASEPROPERTYEX(DB_NAME(), 'Status'),
    [Updateability] = DATABASEPROPERTYEX(DB_NAME(), 'Updateability'),
    [UserAccess] = DATABASEPROPERTYEX(DB_NAME(), 'UserAccess'),
    [Compatibility Level] =
                           CASE
                             WHEN DB_Compatibility = 80 THEN '80 (SQL Server 2000)'
                             WHEN DB_Compatibility = 90 THEN '90 (SQL Server 2005)'
                             WHEN DB_Compatibility = 100 THEN '100 (SQL Server 2008)'
                             WHEN DB_Compatibility = 110 THEN '110 (SQL Server 2012)'
                             WHEN DB_Compatibility = 120 THEN '120 (SQL Server 2014)'
                             WHEN DB_Compatibility = 130 THEN '130 (SQL Server 2016)'
                             WHEN DB_Compatibility = 140 THEN '140 (SQL Server 2017)'
                             WHEN DB_Compatibility = 150 THEN '150 (SQL Server 2019)'
                             WHEN DB_Compatibility = 160 THEN '160 (SQL Server 2022)'
                           END,
    [Page Verification] = page_verify_desc,
    [Log Reuse Status] = log_reuse_wait,
    [DB Collation] = DATABASEPROPERTYEX(DB_NAME(), 'Collation')
  FROM @Sysdatabases


  -- SQL Database high level part 2
  SELECT
    '[ DB_Total_Size ]' = ' [ ' +
    CASE
      WHEN @Complete_DB_Size < 1024 THEN CAST(@Complete_DB_Size AS varchar(10)) + ' KB'
      WHEN @Complete_DB_Size < 1048576 THEN CAST(CAST(@Complete_DB_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
      WHEN @Complete_DB_Size < 1073741824 THEN CAST(CAST(@Complete_DB_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
      ELSE CAST(CAST(@Complete_DB_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
    END + ' ]',
    '=' = '=',
    [DB_Used_Size] =
                    CASE
                      WHEN @Used_Size < 1024 THEN CAST(@Used_Size AS varchar(10)) + ' KB'
                      WHEN @Used_Size < 1048576 THEN CAST(CAST(@Used_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                      WHEN @Used_Size < 1073741824 THEN CAST(CAST(@Used_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                      ELSE CAST(CAST(@Used_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                    END +
    ' (' + CAST(CAST((@Used_Size / @Complete_DB_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + ' %)',
    '+' = '+',
    [DB_Free_Size] =
                    CASE
                      WHEN @Free_Size < 1024 THEN CAST(@Free_Size AS varchar(10)) + ' KB'
                      WHEN @Free_Size < 1048576 THEN CAST(CAST(@Free_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                      WHEN @Free_Size < 1073741824 THEN CAST(CAST(@Free_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                      ELSE CAST(CAST(@Free_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                    END +
    ' (' + CAST(CAST((@Free_Size / @Complete_DB_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + ' %)'

  SELECT
    '[ DB_Total_Size ]' = ' [ ' +
    CASE
      WHEN @Complete_DB_Size < 1024 THEN CAST(@Complete_DB_Size AS varchar(10)) + ' KB'
      WHEN @Complete_DB_Size < 1048576 THEN CAST(CAST(@Complete_DB_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
      WHEN @Complete_DB_Size < 1073741824 THEN CAST(CAST(@Complete_DB_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
      ELSE CAST(CAST(@Complete_DB_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
    END + ' ]',
    '=' = '=',
    '         Data  (%)   ' =
                             CASE
                               WHEN @Data_Size < 1024 THEN CAST(@Data_Size AS varchar(10)) + ' KB'
                               WHEN @Data_Size < 1048576 THEN CAST(CAST(@Data_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                               WHEN @Data_Size < 1073741824 THEN CAST(CAST(@Data_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                               ELSE CAST(CAST(@Data_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                             END + ' (' +
    CAST(CAST((@Data_Size / @Complete_DB_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + ' %)',
    '[' = '[',
    ' Data Used  (     %     ) ' =
                                  CASE
                                    WHEN @Data_Used_Size < 1024 THEN CAST(@Data_Used_Size AS varchar(10)) + ' KB'
                                    WHEN @Data_Used_Size < 1048576 THEN CAST(CAST(@Data_Used_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                                    WHEN @Data_Used_Size < 1073741824 THEN CAST(CAST(@Data_Used_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                                    ELSE CAST(CAST(@Data_Used_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                                  END + ' ('
    + CAST(CAST((@Data_Used_Size / @Data_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + ' %)',
    ' Data Free    (     %      ) ' =
                                     CASE
                                       WHEN @Data_Free_Size < 1024 THEN CAST(@Data_Free_Size AS varchar(10)) + ' KB'
                                       WHEN @Data_Free_Size < 1048576 THEN CAST(CAST(@Data_Free_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                                       WHEN @Data_Free_Size < 1073741824 THEN CAST(CAST(@Data_Free_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                                       ELSE CAST(CAST(@Data_Free_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                                     END + ' ('
    + CAST(CAST((@Data_Free_Size / @Data_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + '%)',
    ']' = ']',
    '+' = '+',
    '         Log  ( % )  ' =
                             CASE
                               WHEN @Log_Size < 1024 THEN CAST(@Log_Size AS varchar(10)) + ' KB'
                               WHEN @Log_Size < 1048576 THEN CAST(CAST(@Log_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                               WHEN @Log_Size < 1073741824 THEN CAST(CAST(@Log_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                               ELSE CAST(CAST(@Log_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                             END + ' (' +
    CAST(CAST((@Log_Size / @Complete_DB_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + ' %)',
    '[' = '['
    --,'[ (  Log Used  ,     %     ); (  Log Free  ,     %      ) ]' = '[ (' +
    ,
    '  Log Used    (     %     ) ' =
                                    CASE
                                      WHEN @Log_Used_Size < 1024 THEN CAST(@Log_Used_Size AS varchar(10)) + ' KB'
                                      WHEN @Log_Used_Size < 1048576 THEN CAST(CAST(@Log_Used_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                                      WHEN @Log_Used_Size < 1073741824 THEN CAST(CAST(@Log_Used_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                                      ELSE CAST(CAST(@Log_Used_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                                    END + ' ('
    + CAST(CAST((@Log_Used_Size / @Log_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + ' %)',
    'Log Free    (      %      ) ' =
                                    CASE
                                      WHEN @Log_Free_Size < 1024 THEN CAST(@Log_Free_Size AS varchar(10)) + ' KB'
                                      WHEN @Log_Free_Size < 1048576 THEN CAST(CAST(@Log_Free_Size / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                                      WHEN @Log_Free_Size < 1073741824 THEN CAST(CAST(@Log_Free_Size / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                                      ELSE CAST(CAST(@Log_Free_Size / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                                    END + ' ('
    + CAST(CAST((@Log_Free_Size / @Log_Size) * 100 AS numeric(20, 3)) AS varchar(50)) + ' %)',
    ']' = ']'


  SELECT
    [Data Files (Filegroups)] = CAST(@DB_Files_Count AS varchar(200)) + ' (' + CAST(@File_group_Count AS varchar(50)) + ')',
    [Log Files (Virtual Log Files)] = CAST(@Log_Files_Count AS varchar(50)) + ' (' + CAST(@Virtual_Log_Files_Count AS varchar(100)) + ')',
    '       ' = '      ',
    [Last Full Backup] = @Full_Backup_Summary,
    [Differential Backup] = @Differential_Backup_Summary,
    [Last Log Backup] = @Log_Backup_Summary


  --Filegroup information
  SELECT
    [File Group] = filegroup,
    [Files Count] = COUNT(*),
    [Size_kb] =
               CASE
                 WHEN SUM(size_kb) < 1024 THEN CAST(SUM(size_kb) AS varchar(10)) + ' KB'
                 WHEN SUM(size_kb) < 1048576 THEN CAST(CAST(SUM(size_kb) / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                 WHEN SUM(size_kb) < 1073741824 THEN CAST(CAST(SUM(size_kb) / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                 ELSE CAST(CAST(SUM(size_kb) / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
               END
  FROM @Sysfiles
  WHERE filegroup LIKE @File_Group_Filter
  GROUP BY filegroup
  ORDER BY SUM(size_kb) DESC

  --Database Size information
  SELECT --[Database Name] = DB_NAME(),
    [Logical Filename] = name,
    [Physical Location] = SUBSTRING(filename, 1, LEN(filename) - CHARINDEX('\', REVERSE(filename), 1)),
    [Physical Filename] = SUBSTRING(filename, LEN(filename) - CHARINDEX('\', REVERSE(filename), 1) + 2, LEN(filename)),
    [File Type] = Filetype + ' (' + RIGHT(filename, 4) + ')',
    [Total Size] =
                  CASE
                    WHEN size_kb < 1024 THEN CAST((size_kb) AS varchar(10)) + ' KB'
                    WHEN size_kb < 1048576 THEN CAST(CAST((size_kb) / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                    WHEN size_kb < 1073741824 THEN CAST(CAST((size_kb) / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                    ELSE CAST(CAST((size_kb) / 1073741824.0 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                  END,
    [Used Space] =
                  CASE
                    WHEN used_size_kb < 1024 THEN CAST((used_size_kb) AS varchar(10)) + ' KB'
                    WHEN used_size_kb < 1048576 THEN CAST(CAST((used_size_kb) / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                    WHEN used_size_kb < 1073741824 THEN CAST(CAST((used_size_kb) / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                    ELSE CAST(CAST((used_size_kb) / 1073741824 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                  END,
    [Free Space] =
                  CASE
                    WHEN free_size_kb < 1024 THEN CAST((free_size_kb) AS varchar(10)) + ' KB'
                    WHEN free_size_kb < 1048576 THEN CAST(CAST((free_size_kb) / 1024.0 AS numeric(10, 3)) AS varchar(20)) + ' MB'
                    WHEN free_size_kb < 1073741824 THEN CAST(CAST((free_size_kb) / 1048576.0 AS numeric(10, 3)) AS varchar(20)) + ' GB'
                    ELSE CAST(CAST((free_size_kb) / 1073741824 AS numeric(10, 3)) AS varchar(20)) + ' TB'
                  END,
    [Free_Space(%)] = CAST((free_size_kb * 1.00 / size_kb) * 100 AS numeric(30, 2)),
    [File_Growth] =
                   CASE
                     WHEN growth LIKE '__' THEN CAST(growth AS varchar(100)) + ' %'
                     WHEN growth = 0 THEN '***Disabled***'
                     ELSE CAST(growth * 8 / 1024 AS varchar(200)) + ' MB'
                   END,
    [Max Growth] =
                  CASE
                    WHEN maxsize_mb = -1 THEN 'Unlimited'
                    WHEN maxsize_mb = 0 THEN 'No Growth'
                    WHEN maxsize_mb = 2097152 THEN '2 TB'
                    ELSE CAST(maxsize_mb AS varchar(50)) + ' MB'
                  END,
    [File Group] = filegroup
  FROM @Sysfiles
  WHERE filegroup LIKE @File_Group_Filter
  ORDER BY size_kb DESC





  SELECT
    [IsAutoClose] =
                   CASE
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoClose') = 0 THEN 'False'
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoClose') = 1 THEN 'True [**** NOT RECOMMENDED ****]'
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoClose') IS NULL THEN '**Input not valid**'
                   END,
    [IsAutoCreateStatistics] =
                              CASE
                                WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatistics') = 0 THEN 'False [**** Consider to Enable ****]'
                                WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatistics') = 1 THEN 'True'
                                WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatistics') IS NULL THEN '**Input not valid**'
                              END,
    [IsAutoCreateStatisticsIncremental] =
                                         CASE
                                           WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatisticsIncremental') = 0 THEN 'False'
                                           WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatisticsIncremental') = 1 THEN 'True'
                                           WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoCreateStatisticsIncremental') IS NULL THEN '**Input not valid**'
                                         END,
    [IsAutoShrink] =
                    CASE
                      WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoShrink') = 0 THEN 'False'
                      WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoShrink') = 1 THEN 'True [**** NOT RECOMMENDED ****]'
                      WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoShrink') IS NULL THEN '**Input not valid**'
                    END,
    [IsAutoUpdateStatistics] =
                              CASE
                                WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoUpdateStatistics') = 0 THEN 'False'
                                WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoUpdateStatistics') = 1 THEN 'True'
                                WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsAutoUpdateStatistics') IS NULL THEN '**Input not valid**'
                              END



  SELECT
    [IsMergePublished] =
                        CASE
                          WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsMergePublished') = 0 THEN 'False'
                          WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsMergePublished') = 1 THEN 'True [The tables of a database can be published for merge replication, if replication is installed]'
                          WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsMergePublished') IS NULL THEN '**Input not valid**'
                        END,
    [IsPublished] =
                   CASE
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsPublished') = 0 THEN 'False'
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsPublished') = 1 THEN 'True [The tables of the database can be published for snapshot or transactional replication, if replication is installed.]'
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsPublished') IS NULL THEN '**Input not valid**'
                   END,
    [IsSubscribed] =
                    CASE
                      WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsSubscribed') = 0 THEN 'False'
                      WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsSubscribed') = 1 THEN 'True [Database is subscribed to a publication.]'
                      WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsSubscribed') IS NULL THEN '**Input not valid**'
                    END


  SELECT
    [IsFulltextEnabled] =
                         CASE
                           WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsFulltextEnabled') = 0 THEN 'False'
                           WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsFulltextEnabled') = 1 THEN 'True'
                           WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsFulltextEnabled') IS NULL THEN '**Input not valid**'
                         END,
    [IsInStandBy] =
                   CASE
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsInStandBy') = 0 THEN 'False'
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsInStandBy') = 1 THEN 'True [Database is online as read-only, with restore log allowed]'
                     WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsInStandBy') IS NULL THEN '**Input not valid**'
                   END,
    [IsParameterizationForced] =
                                CASE
                                  WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsParameterizationForced') = 0 THEN 'False'
                                  WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsParameterizationForced') = 1 THEN 'True [PARAMETERIZATION database SET option is FORCED.]'
                                  WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsParameterizationForced') IS NULL THEN '**Input not valid**'
                                END,
    [IsTornPageDetectionEnabled] =
                                  CASE
                                    WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsTornPageDetectionEnabled') = 0 THEN 'False'
                                    WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsTornPageDetectionEnabled') = 1 THEN 'True'
                                    WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsTornPageDetectionEnabled') IS NULL THEN '**Input not valid**'
                                  END,
    [IsXTPSupported] =
                      CASE
                        WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsXTPSupported') = 0 THEN 'False'
                        WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsXTPSupported') = 1 THEN 'True [Supports In-Memory OLTP]'
                        WHEN DATABASEPROPERTYEX(DB_NAME(), 'IsXTPSupported') IS NULL THEN '**Input not valid**'
                      END
END TRY
BEGIN CATCH
  SELECT
    ERROR_NUMBER() AS ERROR_NUMBER,
    ERROR_SEVERITY() AS ERROR_SEVERITY,
    ERROR_STATE() AS ERROR_STATE,
    ERROR_PROCEDURE() AS ERROR_PROCEDURE,
    ERROR_MESSAGE() AS ERROR_MESSAGE,
    ERROR_LINE() AS ERROR_LINE;
END CATCH;
