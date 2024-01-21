/********************************************************************************************
Author: L.S.N. Sandeep Kumar. Sangineedy
email:sangineedy@gmail.com
Purpose: Get Consolidated SQL DB Backup (Full, Differential, Log, File Group, Differential_File, Partial, Differential File) information
Compatible & Tested SQL Versions: 2005, 2008, 2008 R2, 2012, 2014, 2016, 2017, 2019 & 2022

Usage: 
1. Open SQL Server Management Studio (SSMS) and connect to SQL Server.
2. Click on “New Query”, copy the complete code, paste it & run (Complete code). 
3. Enter the Parameter values as explained below [ (SQL Backup file path (Local/Remote) with backup file ) & Backup File ID]

	@DB_Backup_File = '<backup file located folder >\Test_DB.bak' <-- Enter the Backup file name
	@Backup_File_id =  1 (Default) <-- If specific backup file contains multiple backups on same file. you may specify specific Position to analyze
	
Description: This Script reads [ READHEADERONLY & FILELISTONLY ] information of any SQL Server database backup (Full, Differential, Log, File Group, Differential File, Partial, Differential) File information and displays in friendly way.
********************************************************************************************/

DECLARE @DB_Backup_File varchar(4000),
        @Backup_File_id int


SELECT
  @DB_Backup_File = '',
  @Backup_File_id = 1

DECLARE @Header_Only_Final_Result TABLE (
  Sl_No int IDENTITY (1, 1),
  Backup_Information varchar(4000),
  Backup_Value varchar(4000),
  Value_Description varchar(4000)
)

DECLARE @SQL_Cmd nvarchar(4000),
        @DB_Backup_Size_Total varchar(50),
        @SQL_Version varchar(50),
        @Product_Major_number int,
        @Product_Minor_number int,
        @Product_Build_number int,
        @Product_Revision_number int,
        @Current_SQL_Version varchar(50),
        @Backup_SQL_Version varchar(50),
        @Backup_Duration_Sec bigint,
        @Backup_Positions_Count int

SELECT
  @SQL_Version = CAST(SERVERPROPERTY('ProductVersion') AS varchar(50))

SELECT
  @Product_Major_number = PARSENAME(CONVERT(varchar(32), @SQL_Version), 4),
  @Product_Minor_number = PARSENAME(CONVERT(varchar(32), @SQL_Version), 3),
  @Product_Build_number = PARSENAME(CONVERT(varchar(32), @SQL_Version), 2),
  @Product_Revision_number = PARSENAME(CONVERT(varchar(32), @SQL_Version), 1)



SELECT
  @SQL_Cmd = 'RESTORE HEADERONLY FROM DISK = ''' + @DB_Backup_File + ''''



/*************************** Load HEADERONLY ******************************/

IF OBJECT_ID('tempdb..##RESTORE_HEADERONLY_FROM_DISK', 'U') IS NOT NULL
  DROP TABLE ##RESTORE_HEADERONLY_FROM_DISK
CREATE TABLE ##RESTORE_HEADERONLY_FROM_DISK (
  BackupName nvarchar(128),
  BackupDescription nvarchar(255),
  BackupType smallint,
  ExpirationDate datetime,
  Compressed bit,
  Position smallint,
  DeviceType tinyint,
  UserName nvarchar(128),
  ServerName nvarchar(128),
  DatabaseName nvarchar(128),
  DatabaseVersion int,
  DatabaseCreationDate datetime,
  BackupSize numeric(20, 0),
  FirstLSN numeric(25, 0),
  LastLSN numeric(25, 0),
  CheckpointLSN numeric(25, 0),
  DatabaseBackupLSN numeric(25, 0),
  BackupStartDate datetime,
  BackupFinishDate datetime,
  SortOrder smallint,
  CodePage smallint,
  UnicodeLocaleId int,
  UnicodeComparisonStyle int,
  CompatibilityLevel tinyint,
  SoftwareVendorId int,
  SoftwareVersionMajor int,
  SoftwareVersionMinor int,
  SoftwareVersionBuild int,
  MachineName nvarchar(128),
  Flags int,
  BindingID uniqueidentifier,
  RecoveryForkID uniqueidentifier,
  Collation nvarchar(128),
  FamilyGUID uniqueidentifier,
  HasBulkLoggedData bit,
  IsSnapshot bit,
  IsReadOnly bit,
  IsSingleUser bit,
  HasBackupChecksums bit,
  IsDamaged bit,
  BeginsLogChain bit,
  HasIncompleteMetaData bit,
  IsForceOffline bit,
  IsCopyOnly bit,
  FirstRecoveryForkID uniqueidentifier,
  ForkPointLSN numeric(25, 0) NULL,
  RecoveryModel nvarchar(60),
  DifferentialBaseLSN numeric(25, 0) NULL,
  DifferentialBaseGUID uniqueidentifier,
  BackupTypeDescription nvarchar(60),
  BackupSetGUID uniqueidentifier NULL,
  CompressedBackupSize bigint
)

IF (@Product_Major_number = 9)
  ALTER TABLE ##RESTORE_HEADERONLY_FROM_DISK DROP COLUMN [CompressedBackupSize];
IF (@Product_Major_number = 11)
  ALTER TABLE ##RESTORE_HEADERONLY_FROM_DISK ADD [Containment] tinyint;
ELSE
IF ((@Product_Major_number = 12)
  AND (@Product_Build_number < 2342))
  ALTER TABLE ##RESTORE_HEADERONLY_FROM_DISK ADD [Containment] tinyint;
ELSE
IF (@Product_Major_number >= 12)
BEGIN
  ALTER TABLE ##RESTORE_HEADERONLY_FROM_DISK ADD [Containment] tinyint;
  ALTER TABLE ##RESTORE_HEADERONLY_FROM_DISK ADD [KeyAlgorithm] nvarchar(32);
  ALTER TABLE ##RESTORE_HEADERONLY_FROM_DISK ADD [EncryptorThumbprint] varbinary(20);
  ALTER TABLE ##RESTORE_HEADERONLY_FROM_DISK ADD [EncryptorType] nvarchar(32);
END


INSERT INTO ##RESTORE_HEADERONLY_FROM_DISK
EXEC (@SQL_Cmd)


/*************************** Load HEADERONLY ******************************/


/*************************** Load FILELISTONLY ******************************/


SELECT
  @SQL_Cmd = 'RESTORE FILELISTONLY FROM DISK = ''' + @DB_Backup_File + ''''
IF OBJECT_ID('tempdb..##bkp_fileListTable', 'U') IS NOT NULL
  DROP TABLE ##bkp_fileListTable
CREATE TABLE ##bkp_fileListTable (
  [LogicalName] nvarchar(128),
  [PhysicalName] nvarchar(260),
  [Type] varchar(100),
  [FileGroupName] nvarchar(128),
  [Size] numeric(30, 0),
  [MaxSize] numeric(30, 0),
  [FileID] bigint,
  [CreateLSN] numeric(25, 0),
  [DropLSN] numeric(25, 0),
  [UniqueID] uniqueidentifier,
  [ReadOnlyLSN] numeric(25, 0),
  [ReadWriteLSN] numeric(25, 0),
  [BackupSizeInBytes] bigint,
  [SourceBlockSize] int,
  [FileGroupID] int,
  [LogGroupGUID] uniqueidentifier,
  [DifferentialBaseLSN] numeric(25, 0),
  [DifferentialBaseGUID] uniqueidentifier,
  [IsReadOnly] bit,
  [IsPresent] bit,
  [TDEThumbprint] varbinary(32)
)

IF (@Product_Major_number <= 9)
  ALTER TABLE ##bkp_fileListTable DROP COLUMN TDEThumbprint;
ELSE
IF (@Product_Major_number >= 13)
  ALTER TABLE ##bkp_fileListTable ADD [Containment] nvarchar(360);

INSERT INTO ##bkp_fileListTable
EXEC (@SQL_Cmd)

/*************************** Load FILELISTONLY ******************************/

/*************************** Result for HEADERONLY ******************************/


SELECT
  @Backup_Positions_Count = COUNT(*)
FROM ##RESTORE_HEADERONLY_FROM_DISK

DELETE FROM ##RESTORE_HEADERONLY_FROM_DISK
WHERE Position <> @Backup_File_id

SELECT
  @Current_SQL_Version =
                        CASE
                          WHEN @Product_Major_number = 9 THEN ' 2005 (' + CAST(@SQL_Version AS varchar(50)) + ')'
                          WHEN @Product_Major_number = 10 AND
                            @Product_Minor_number = 50 THEN ' 2008 R2 (' + CAST(@SQL_Version AS varchar(50)) + ')'
                          WHEN @Product_Major_number = 10 THEN ' 2008 (' + CAST(@SQL_Version AS varchar(50)) + ')'
                          WHEN @Product_Major_number = 11 THEN ' 2012 (' + CAST(@SQL_Version AS varchar(50)) + ')'
                          WHEN @Product_Major_number = 12 THEN ' 2014 (' + CAST(@SQL_Version AS varchar(50)) + ')'
                          WHEN @Product_Major_number = 13 THEN ' 2016 (' + CAST(@SQL_Version AS varchar(50)) + ')'
                          WHEN @Product_Major_number = 14 THEN ' 2017 (' + CAST(@SQL_Version AS varchar(50)) + ')'
                        END
SELECT
  @Backup_SQL_Version =
                       CASE
                         WHEN SoftwareVersionMajor = 9 THEN ' 2005 (' + CAST(SoftwareVersionMajor AS varchar(50)) + '.' + CAST(SoftwareVersionMinor AS varchar(50)) + '.' + CAST(SoftwareVersionBuild AS varchar(50)) + ')'
                         WHEN SoftwareVersionMajor = 10 AND
                           SoftwareVersionMinor = 50 THEN ' 2008 R2 (' + CAST(SoftwareVersionMajor AS varchar(50)) + '.' + CAST(SoftwareVersionMinor AS varchar(50)) + '.' + CAST(SoftwareVersionBuild AS varchar(50)) + ')'
                         WHEN SoftwareVersionMajor = 10 THEN ' 2008 (' + CAST(SoftwareVersionMajor AS varchar(50)) + '.' + CAST(SoftwareVersionMinor AS varchar(50)) + '.' + CAST(SoftwareVersionBuild AS varchar(50)) + ')'
                         WHEN SoftwareVersionMajor = 11 THEN ' 2012 (' + CAST(SoftwareVersionMajor AS varchar(50)) + '.' + CAST(SoftwareVersionMinor AS varchar(50)) + '.' + CAST(SoftwareVersionBuild AS varchar(50)) + ')'
                         WHEN SoftwareVersionMajor = 12 THEN ' 2014 (' + CAST(SoftwareVersionMajor AS varchar(50)) + '.' + CAST(SoftwareVersionMinor AS varchar(50)) + '.' + CAST(SoftwareVersionBuild AS varchar(50)) + ')'
                         WHEN SoftwareVersionMajor = 13 THEN ' 2016 (' + CAST(SoftwareVersionMajor AS varchar(50)) + '.' + CAST(SoftwareVersionMinor AS varchar(50)) + '.' + CAST(SoftwareVersionBuild AS varchar(50)) + ')'
                         WHEN SoftwareVersionMajor = 14 THEN ' 2017 (' + CAST(SoftwareVersionMajor AS varchar(50)) + '.' + CAST(SoftwareVersionMinor AS varchar(50)) + '.' + CAST(SoftwareVersionBuild AS varchar(50)) + ')'
                       END
FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Qurying SQL Instance Version',
    CAST(SERVERPROPERTY('servername') AS varchar(500)) + ' [ ' + @Current_SQL_Version + ' ]',
    'Currently Running SQL Instance'

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    [Backup File Property] = 'Backup File Path',
    SUBSTRING(@DB_Backup_File, 1, LEN(@DB_Backup_File) - CHARINDEX('\', REVERSE(@DB_Backup_File), 1)),
    'Backup file residing location'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    [Backup File Property] = 'Backup File Name',
    SUBSTRING(@DB_Backup_File, LEN(@DB_Backup_File) - (CHARINDEX('\', REVERSE(@DB_Backup_File), 1) - 2), LEN(@DB_Backup_File)),
    'Backup file Name'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    [Backup File Property] = 'Backup taken Host name',
    [Backup Value] = MachineName,
    'Name of the computer that performed the backup operation'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    [Backup File Property] = 'Backup taken SQL Instance',
    [Backup Value] = ServerName + ' [ ' + @Backup_SQL_Version + ' ] ',
    [Description] = 'Name of the server that wrote the backup set.'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Database Name (Compatibility)',
    DatabaseName + ' (' + CAST(CompatibilityLevel AS varchar(5)) + ')',
    'Name of the database (Compatibility level) of Backuped DB'
  FROM ##RESTORE_HEADERONLY_FROM_DISK


INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup Position',
    'Total Backups: [ ' + CAST(@Backup_Positions_Count AS varchar(5))
    + ' ]; Current Position: [ ' + CAST(@Backup_File_id AS varchar(5)) + ' ]',
    'Total Available Backups in this Backup File; Current Backup position'


INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup Type',
    CASE
      WHEN BackupType = 1 THEN 'Full Database Backup'
      WHEN BackupType = 2 THEN 'Transaction log'
      WHEN BackupType = 4 THEN 'File'
      WHEN BackupType = 5 THEN 'Differential database'
      WHEN BackupType = 6 THEN 'Differential file'
      WHEN BackupType = 7 THEN 'Partial'
      WHEN BackupType = 8 THEN 'Differential partial'
    END,
    'DB Backup Type'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Database Created date',
    CONVERT(varchar, DatabaseCreationDate) + ' (' + CAST(DATEDIFF(DD, DatabaseCreationDate, GETDATE()) AS varchar(500)) + ' Days old)',
    'Date and time the database was created'
  FROM ##RESTORE_HEADERONLY_FROM_DISK



INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup Initiated S/W',
    CASE
      WHEN CAST(SoftwareVendorId AS varchar) = '4608' THEN 'Microsoft SQL Server'
      ELSE CAST(SoftwareVendorId AS varchar(50))
    END,
    'Software that initiated DB Backup'
  FROM ##RESTORE_HEADERONLY_FROM_DISK



INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup Start Date',
    CONVERT(varchar(50), BackupStartDate, 113) +
    ' (' + CAST(DATEDIFF(DD, BackupStartDate, GETDATE()) AS varchar(500)) + ' Days)',
    'Date and time that the backup operation began'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup Finished Date',
    CONVERT(varchar(50), BackupFinishDate, 113) +
    ' (' + CAST(DATEDIFF(DD, BackupFinishDate, GETDATE()) AS varchar(500)) + ' Days)',
    'Date and time that the backup operation completed'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

SELECT
  @Backup_Duration_Sec = DATEDIFF(SS, BackupStartDate, BackupFinishDate)
FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup Duration',
    CAST((@Backup_Duration_Sec / 3600) AS varchar(50)) + ' Hours '
    + CAST((@Backup_Duration_Sec % 3600) / 60 AS varchar(50)) + ' Minutes '
    + CAST((@Backup_Duration_Sec % 60) AS varchar(50)) + ' Seconds ',
    'Time taken for Backup operation to complete'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup Expiration Date',
    ISNULL(CONVERT(varchar, ExpirationDate) + ' (' + CAST(DATEDIFF(DD, ExpirationDate, GETDATE()) AS varchar(500)) + ') Days', 'Backup will never Expiration'),
    'Expiration date for the backup set'
  FROM ##RESTORE_HEADERONLY_FROM_DISK


INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'DB Recovery Model',
    RecoveryModel,
    'Recovery model for the Database'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'DB Collation',
    Collation,
    'Collation used by the database'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'DB Backup Performed by',
    UserName,
    'User name that performed the backup operation'
  FROM ##RESTORE_HEADERONLY_FROM_DISK


INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Database size',
    CASE
      WHEN SUM(Size) < 1024 THEN CAST(SUM(Size) AS varchar(10)) + ' Bytes'
      WHEN SUM(Size) < 1048576 THEN CAST(CAST(SUM(Size) / 1024.0 AS numeric(10, 2)) AS varchar(20)) + ' KB'
      WHEN SUM(Size) < 1073741824 THEN CAST(CAST(SUM(Size) / 1048576.0 AS numeric(10, 2)) AS varchar(20)) + ' MB'
      WHEN SUM(Size) < 1099511627776 THEN CAST(CAST(SUM(Size) / 1073741824.0 AS numeric(10, 2)) AS varchar(20)) + ' GB'
      ELSE CAST(CAST(SUM(Size) / 1099511627776 AS numeric(10, 2)) AS varchar(20)) + ' TB'
    END,
    'Database size'
  FROM ##bkp_fileListTable

INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'DB Backup size',
    CASE
      WHEN BackupSize < 1024 THEN CAST(BackupSize AS varchar(10)) + ' Bytes'
      WHEN BackupSize < 1048576 THEN CAST(CAST(BackupSize / 1024.0 AS numeric(10, 2)) AS varchar(20)) + ' KB'
      WHEN BackupSize < 1073741824 THEN CAST(CAST(BackupSize / 1048576.0 AS numeric(10, 2)) AS varchar(20)) + ' MB'
      WHEN BackupSize < 1099511627776 THEN CAST(CAST(BackupSize / 1073741824.0 AS numeric(10, 2)) AS varchar(20)) + ' GB'
      ELSE CAST(CAST(BackupSize / 1099511627776 AS numeric(10, 2)) AS varchar(20)) + ' TB'
    END,
    'DB Backup Size ***(without Compression)***'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

IF (@Product_Major_number > 9)
BEGIN
  INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
    SELECT
      'Compressed DB Backup size',
      CASE
        WHEN Compressed = 1 THEN '[ Yes ]  '
        ELSE ' [ No ]  '
      END
      + CASE
        WHEN CompressedBackupSize < 1024 THEN CAST(BackupSize AS varchar(10)) + ' Bytes'
        WHEN CompressedBackupSize < 1048576 THEN CAST(CAST(CompressedBackupSize / 1024.0 AS numeric(10, 2)) AS varchar(20)) + ' KB'
        WHEN CompressedBackupSize < 1073741824 THEN CAST(CAST(CompressedBackupSize / 1048576.0 AS numeric(10, 2)) AS varchar(20)) + ' MB'
        WHEN CompressedBackupSize < 1099511627776 THEN CAST(CAST(CompressedBackupSize / 1073741824.0 AS numeric(10, 2)) AS varchar(20)) + ' GB'
        ELSE CAST(CAST(CompressedBackupSize / 1099511627776 AS numeric(10, 2)) AS varchar(20)) + ' TB'
      END,
      'Compressed DB Backup Size without Compression'
    FROM ##RESTORE_HEADERONLY_FROM_DISK
END


INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'DB Backup Name',
    BackupName,
    'Backup set name'
  FROM ##RESTORE_HEADERONLY_FROM_DISK


INSERT INTO @Header_Only_Final_Result (Backup_Information, Backup_Value, Value_Description)
  SELECT
    'Backup description',
    ISNULL(BackupDescription, ''),
    'Backup set description'
  FROM ##RESTORE_HEADERONLY_FROM_DISK

SELECT
  *
FROM @Header_Only_Final_Result


/*************************** Result for FILELISTONLY ******************************/

SELECT
  [FileID],
  [LogicalName],
  [File Path] = SUBSTRING([PhysicalName], 1, LEN([PhysicalName]) - CHARINDEX('\', REVERSE([PhysicalName]), 1)),
  [File Name] = SUBSTRING([PhysicalName], LEN([PhysicalName]) - (CHARINDEX('\', REVERSE([PhysicalName]), 1) - 2), LEN([PhysicalName])),
  [Type] =
          CASE Type
            WHEN 'D' THEN 'Database'
            WHEN 'F' THEN 'File and Filegroup'
            WHEN 'L' THEN 'Transaction Log'
            WHEN 'I' THEN 'Differential'
          END,
  [DB_FileSize] =
                 CASE
                   WHEN Size < 1024 THEN CAST(Size AS varchar(10)) + ' Bytes'
                   WHEN Size < 1048576 THEN CAST(CAST(Size / 1024.0 AS numeric(10, 2)) AS varchar(20)) + ' KB'
                   WHEN Size < 1073741824 THEN CAST(CAST(Size / 1048576.0 AS numeric(10, 2)) AS varchar(20)) + ' MB'
                   ELSE CAST(CAST(Size / 1073741824 AS numeric(10, 2)) AS varchar(20)) + ' GB'
                 END,
  [BackupSize_ForFile] =
                        CASE
                          WHEN BackupSizeInBytes < 1024 THEN CAST(BackupSizeInBytes AS varchar(10)) + ' Bytes'
                          WHEN BackupSizeInBytes < 1048576 THEN CAST(CAST(BackupSizeInBytes / 1024.0 AS numeric(10, 2)) AS varchar(20)) + ' KB'
                          WHEN BackupSizeInBytes < 1073741824 THEN CAST(CAST(BackupSizeInBytes / 1048576.0 AS numeric(10, 2)) AS varchar(20)) + ' MB'
                          ELSE CAST(CAST(BackupSizeInBytes / 1073741824 AS numeric(10, 2)) AS varchar(20)) + ' GB'
                        END,
  [FileGroupID],
  [FileGroupName],
  [MaxSize] =
             CASE
               WHEN MaxSize < 1024 THEN CAST(MaxSize AS varchar(10)) + ' Bytes'
               WHEN MaxSize < 1048576 THEN CAST(CAST(MaxSize / 1024.0 AS numeric(10, 2)) AS varchar(20)) + ' KB'
               WHEN MaxSize < 1073741824 THEN CAST(CAST(MaxSize / 1048576.0 AS numeric(10, 2)) AS varchar(20)) + ' MB'
               WHEN MaxSize < 1099511627776 THEN CAST(CAST(MaxSize / 1073741824.0 AS numeric(10, 2)) AS varchar(20)) + ' GB'
               ELSE CAST(CAST(MaxSize / 1099511627776 AS numeric(10, 2)) AS varchar(20)) + ' TB'
             END
FROM ##bkp_fileListTable
ORDER BY [Size] DESC


DROP TABLE ##bkp_fileListTable
DROP TABLE ##RESTORE_HEADERONLY_FROM_DISK