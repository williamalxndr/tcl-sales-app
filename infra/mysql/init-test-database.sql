-- Development/CI only. Django tests use this separate database with --keepdb.
-- If MYSQL_DATABASE or MYSQL_USER changes, update this file before first startup.
CREATE DATABASE IF NOT EXISTS test_sales CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON test_sales.* TO 'sales'@'%';
