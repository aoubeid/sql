set scan on
set pages 
set feedback off
set heading off
set verify off
set lines 300
set trims on
 
set term on
prompt +--------------------------------------------+
prompt DESCRIPTION:
prompt ============
prompt This script will extract source code for the following source types:
prompt 1. PACKAGE
prompt 2. PACKAGE BODY
prompt 3. FUNCTION
prompt 4. PROCEDURE
prompt The source code will be spooled into a file named after the source name
prompt USAGE:
prompt =====
prompt follow the prompts ...
prompt +---------------------------------------------+
accept dbNmae CHAR PROMPT "Enter Database : "
accept pkgName prompt "Enter Procedure Or Package Name: "
accept theOwner prompt "Enter The Owner Name: "
accept type prompt "Enter type Of the source [PACKAGE, PACKAGE BODY, PROCEDURE, FUNCTION]: "
set term off
 
SELECT DECODE(ROWNUM,1,'CREATE OR REPLACE '||text, text)
FROM   dba_source@&&dbName||'.bfi.admin.ch'
WHERE  name  = UPPER('&&pkgName')
AND    owner = UPPER('&theOwner')
AND    type  = UPPER('&type')
ORDER BY line
 
spool &&pkgName..sql
/
prompt 
/
spool off
 
ed &&pkgName
 
undefine pkgName