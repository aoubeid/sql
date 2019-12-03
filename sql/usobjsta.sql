rem ---------------------------------------------------------------------------
rem  Trivadis AG, Baden-Dättwil/Basel/Bern/Lausanne/Zürich
rem               Düsseldorf/Frankfurt/Freiburg i.Br./Hamburg/München/Stuttgart
rem               Wien
rem               Switzerland/Germany/Austria Internet: http://www.trivadis.com
rem ---------------------------------------------------------------------------
rem $Id: usobjsta.sql 108 2008-11-30 23:45:40Z cha $
rem ---------------------------------------------------------------------------
rem  Group/Privileges.: SYSDBA
rem  Script Name......: usobjsta.sql
rem  Developer........: Urs Meier (UrM)
rem  Date.............: 04.08.1998
rem  Version..........: Oracle Database 11g
rem  Description......: Compile invalid objects
rem  Usage............: 
rem  Input parameters.: 
rem  Output...........: 
rem  Called by........:
rem  Requirements.....: 
rem  Remarks..........: This utility is smarter than
rem                     dbms_utility.compile_schema ;-) which fails
rem                     on different occasions
rem
rem                     It is a good idea to exclude also
rem                     the Oracle Designer Repository Onwer
rem                     from the user-list (next to SYS), since there
rem                     is built-in functionality to re-compile the
rem                     repository.
rem
rem ---------------------------------------------------------------------------
rem Changes:
rem DD.MM.YYYY Developer Change
rem ---------------------------------------------------------------------------
rem 09.12.1998 UrM	 enhanced error handling (Andrea Nann, UBS)
rem
rem 08.01.2000 UrM       Support for Java Classes
rem                      The Oracle Views public_dependency uses Connect By
rem                      which does not work anymore. This is why the old version
rem                      of usobjsta and all the Oracle utilities for compiling
rem                      do not work anymore as soon as you are using java.
rem                      So we use a recursive procedure.
rem                      However, I didn't manage to stop endless
rem                      loops because of ORA-600 if I try to handle it in the
rem                      exception.
rem                      This is why the nesting is hardcoded limited to 10 levels.
rem                      You may want to adjust this with maxNestedLevel.
rem
rem 12.01.2000 AnK       Made some cosmetics to DBMS_OUTPUT
rem 04.09.2002 ThJ       OK for Oracle9i R2
rem 10.09.2003 AnK       OK for 10.1
rem                      (added support for compile SYNONYM/PUBLIC SYNONYM, as
rem                       beginning 10.1 they are dependent)
rem                      (added support for MVIEW compile, missing in previous
rem                       versions already)
rem 01.12.2008 ChA       Fixed header + Formatting
rem 01.12.2008 ChA       OK for 11g
rem ---------------------------------------------------------------------------

store set temp.tmp replace
set serveroutput on size 1000000 verify off linesize 132
ACCEPT TheOwner CHAR PROMPT "Compile invalid object for schema [LSVA]: " DEFAULT 'LSVA'

DECLARE
  eStillInvalid EXCEPTION;
  PRAGMA EXCEPTION_INIT(eStillInvalid,-24344);
  vCursor        INTEGER := DBMS_SQL.Open_Cursor;
  vDummy         INTEGER;
  n              INTEGER;
  maxlevel       INTEGER := 1;
  maxNestedLevel INTEGER := 10;
  errCount       INTEGER := 0;

  TYPE          obj IS RECORD (  obj_id    NUMBER
                               , obj_owner VARCHAR2(30)
                               , obj_name  VARCHAR2(30)
                               , obj_type  VARCHAR2(30)
                               , obj_level NUMBER
                               );

  TYPE          objs IS TABLE OF obj
                        INDEX BY BINARY_INTEGER;

  vobj          obj;
  vobjs         objs;



  PROCEDURE compile_obj(pObj IN obj) IS
      vStatement    VARCHAR2(4000);

  BEGIN

     dbms_output.put(RPAD(substr(pobj.obj_owner,1,30)||'.'||substr(pobj.obj_name,1,30)||' ('||substr(pobj.obj_type,1,30)||')',61,'.'));

     IF (pobj.obj_type = 'FUNCTION') THEN
       vStatement := 'ALTER FUNCTION "'   ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'SYNONYM') THEN
       vStatement := 'ALTER SYNONYM "'    ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'MATERIALIZED VIEW') THEN
       vStatement := 'ALTER MATERIALIZED VIEW"'    ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'PACKAGE') THEN
       vStatement := 'ALTER PACKAGE "'    ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'PACKAGE BODY') THEN
       vStatement := 'ALTER PACKAGE "'    ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE BODY';
     ELSIF (pobj.obj_type = 'PROCEDURE') THEN
       vStatement := 'ALTER PROCEDURE "'  ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'TRIGGER') THEN
       vStatement := 'ALTER TRIGGER "'    ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'TYPE') THEN
       vStatement := 'ALTER TYPE "'       ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'TYPE BODY') THEN
       vStatement := 'ALTER TYPE "'       ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE BODY';
     ELSIF (pobj.obj_type = 'VIEW') THEN
       vStatement := 'ALTER VIEW "'       ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'OPERATOR') THEN
       vStatement := 'ALTER OPERATOR "'   ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'INDEXTYPE') THEN
       vStatement := 'ALTER INDEXTYPE "'  ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'DIMENSION') THEN
       vStatement := 'ALTER DIMENSION "'  ||pobj.obj_owner||'"."'||pobj.obj_name||'" COMPILE';
     ELSIF (pobj.obj_type = 'JAVA CLASS') THEN
       vStatement := 'ALTER JAVA CLASS "' ||pobj.obj_owner||'"."'||pobj.obj_name||'" RESOLVE';
     ELSIF (pobj.obj_type = 'JAVA SOURCE') THEN
        dbms_output.put('...Not compiling Java Source itself');
     ELSE
        dbms_output.put('...unknown type ' ||pobj.obj_type||'!');
     END IF;

     IF (vStatement IS NOT NULL) THEN
       BEGIN
         DBMS_SQL.Parse(vCursor,vStatement,DBMS_SQL.Native);
         vDummy := DBMS_SQL.Execute(vCursor);
         dbms_output.put('...OK');
       EXCEPTION
         WHEN eStillInvalid THEN
            dbms_output.put('...remains invalid');
           errCount := errCount + 1;
         WHEN OTHERS THEN
            dbms_output.put('...ERROR!');
            dbms_output.new_line;
            dbms_output.put('...Problem '||SQLErrm(SQLCode)||' (Error in '||pobj.obj_type||')');
           errCount := errCount + 1;
       END;
     END IF;
     dbms_output.new_line;
  END;


  PROCEDURE get_obj (pObj IN obj, pLevel IN NUMBER Default 1) IS

  BEGIN
     vobjs(pobj.obj_id).obj_id    := pobj.obj_id;
     vobjs(pobj.obj_id).obj_owner := pobj.obj_owner;
     vobjs(pobj.obj_id).obj_name  := pobj.obj_name;
     vobjs(pobj.obj_id).obj_type  := pobj.obj_type;
     vobjs(pobj.obj_id).obj_level := pLevel;
     maxlevel := GREATEST(maxlevel,pLevel);

    FOR hieobj IN (SELECT /*+ ordered */ object_id, owner, object_name, object_type
                     FROM dependency$,
                          dba_objects
                    WHERE object_id = d_obj#
                      AND p_obj# = pObj.obj_id
                      AND owner != 'SYS'  /* don't catch standard or java.* */
                      AND status != 'VALID'
                      AND object_type != 'UNDEFINED'
                      AND plevel < maxNestedLevel
                  ) LOOP

       vobj.obj_id    := hieobj.object_id;
       vobj.obj_owner := hieobj.owner;
       vobj.obj_name  := hieobj.object_name;
       vobj.obj_type  := hieobj.object_type;
       get_obj(vobj, pLevel+1 );  -- get the rest

    END LOOP;
  END get_obj;

BEGIN
  -- This is the root or parent of the hierarchie
  FOR invobj IN (SELECT obj.object_id,obj.owner,obj.object_type, obj.object_name
                   FROM dba_objects obj
                  WHERE owner != 'SYS'
                    AND obj.status != 'VALID'
                    AND obj.object_type != 'UNDEFINED'
                    AND owner LIKE UPPER('&TheOwner')
                  ORDER BY owner, last_ddl_time
                 ) LOOP

     vobj.obj_id    := invobj.object_id;
     vobj.obj_owner := invobj.owner;
     vobj.obj_name  := invobj.object_name;
     vobj.obj_type  := invobj.object_type;

     get_obj(vobj);  -- now get the hierarchie

  END LOOP;

  -- compile the objects. loop over the objects with brut force
  FOR i IN 1 .. maxLevel LOOP
    n := vobjs.first();
      FOR j IN 1 .. vobjs.count() LOOP
        IF (vobjs(n).obj_level = i) THEN
          compile_obj(vobjs(n));
        END IF;
        n := vobjs.next(n);
      END LOOP;
  END LOOP;

  dbms_sql.close_cursor(vCursor);
  dbms_output.put_line('Worked on '||to_char(vobjs.Count())||' objects, nested at '||to_char(maxLevel)||' levels');
  dbms_output.put_line(ErrCount||' errors');
END;
/

SELECT owner, status, COUNT(*)
  FROM dba_objects
 WHERE status = 'INVALID'
 GROUP BY owner,status;



set echo off serveroutput off

@temp.tmp



