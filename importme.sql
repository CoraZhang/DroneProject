SHOW VARIABLES LIKE "secure_file_priv";
LOAD DATA INFILE 'C:\ProgramData\MySQL\MySQL Server 8.0\Uploads\Split1.csv' 
INTO TABLE fcc_lic_vw
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
escaped by ''
IGNORE 1 ROWS;