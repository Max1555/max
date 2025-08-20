USE [master]
RESTORE DATABASE [D899_DB] FROM  DISK = N'E:\Backup\db899_05082011.bak' WITH  FILE = 1,  
MOVE N'D899_DAT' TO N'e:\DATA\D899.MDF',  
MOVE N'D899_LOG' TO N'e:\DATA\D899.LDF',  
MOVE N'sysft_D899_fulltext_catalog' TO N'e:\DATA\D899_fulltext_catalog',  
STATS = 5

GO