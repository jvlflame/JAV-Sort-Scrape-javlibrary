
#Import the module, create a data source and a table
Import-Module PSSQLite

$Database = "Z:\git\other\JAV-Sort-Scrape-javlibrary\emby_thumbs\db\actors.sqlite"
$Query = "CREATE TABLE NAMES (
    Fullname VARCHAR(20) PRIMARY KEY,
    Surname TEXT,
    Givenname TEXT,
    Birthdate DATETIME)"

#SQLite will create Names.SQLite for us
Invoke-SqliteQuery -Query $Query -DataSource $Database

# We have a database, and a table, let's view the table info
Invoke-SqliteQuery -DataSource $Database -Query "PRAGMA table_info(NAMES)"