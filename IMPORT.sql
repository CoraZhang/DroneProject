LOAD DATA INFILE 'C:\Users\eizhhas\Desktop\Update Data\Split1.csv' 
INTO TABLE fcc_lic_vw
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
escaped by ''
IGNORE 1 ROWS;