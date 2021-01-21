%include "C:\temp\GIT\macros\*";
%unix_file_list(local_path=C:\temp\hsbc\sas_files.txt,path=/mnt/c/,output=WORK.FILE_LIST_UNIX_BASE,atime=NO);
%unix_file_list(local_path=C:\temp\hsbc\sas_files_lslu.txt,path=/mnt/c/,output=WORK.FILE_LIST_UNIX_LSLU,atime=YES);

/*============================================================================================================*/
/* MERGE THE TWO FILES					                                   								  	  */
/*============================================================================================================*/

proc sql;
	create table unix_file_list_snapshot as
		select 
			a.D_START label="Extract Creation Date DDMONYYYY"
			,a.FILENAME label="Full File Path - DIRECTORY and File"
			,a.DIRECTORY label ="Directory of File"
			,a.GRID_SUB_DIRECTORY label ="SUB Directory"
			,a.GRID_SUB_FILENAME label="SUB Directory of File"
			,a.SHORT_FILENAME label="Filename"
			,a.EXTENSION label="File Extension"
			,a.GROUP label="Group Owner of File"
			,a.PERMISSIONS
			,a.USERNAME label ="User Owner of File"
			,a.SIZE_BYTES
			,a.SIZE_KB
			,a.SIZE_MB
			,a.SIZE_GB
			,a.dttm_modified as DTTM_CREATE
			,b.dttm_modified
			,intck('day', datepart(b.dttm_modified),today()) as DAYS_SINCE_ACCESS 
		from file_list_unix_base as a
			inner join
				file_list_unix_lslu as b
				on a.filename =b.filename
				and a.size_bytes =b.size_bytes;
quit;

/*------------------------------------------------------------------------------------------------------------*/
/* HISTORY STORAGE                                                   								  	  	  */
/* Keeping the history is important for further analysis and DI SCD loader could be used to hold as a    	  */
/* dimension table. Alternatively it could be appended as one table with online requirements.  				  */
/*------------------------------------------------------------------------------------------------------------*/

/*Type2Loader*/
/*delete teh base tabel if it exists for testing and development*/
proc datasets lib=scd_load;
delete unix_file_list_full_dh;
run;

/*Create datetime variables for test example*/
/*DT = Load DT*/
/*VALFROMDT = Valid from date which is set to midnight of the load date*/
%let dt=%sysfunc(date(),date9.):%sysfunc(compress(%sysfunc(time(),time8.0)));
%let valfromdt=%sysfunc(date(),date9.):00:00:00;
%put &dt.;
%put &valfromdt.;

/*Set a libname for the history files to be held. This is set to work for this example and should be a perm location*/
libname scd_load "%sysfunc(pathname(work))";

/*Create a unique key on the merged snapshot*/

/*Create a unique key on the file*/
data unix_file_list_snapshot_key;
set unix_file_list_snapshot;
key + 1;
key2 = key * 100;
run;
/*COMPARE VALUES*/
/*This load is set to compare for any changes on the following:*/
/*	FILENAME*/
/*	SIZE_BYTES*/
/*	DTTM_CREATE */
/*	DTTM_MODIFIED*/
/**/
/*KEEPVARS */
/*This example is set to keey ALL values*/
/**/
/*UPDATETYPE*/
/*This is set to keep a delta only so it will only load any record which has changed. Setting to FULL would*/
/*load everything. Take care when using FULL with a large table which is changing slowly*/
%Type2Loader(
  TargetTable=scd_load.unix_file_list_full_dh, 
  UpdateTable=work.unix_file_list_snapshot_key, 
  FromVar=Valid_From, 
  ToVar=Valid_To, 
  LoadVar=Load_DT, 
  IdVars=Key Key2, 
  CompareVars=filename size_bytes dttm_create dttm_modified, 
  Surrogate_Key_Var=Master_RK,
  ValidFromDT="&valfromdt"dt, 
  ValidToDT='31Dec9999:23:59:59'dt, 
  LoadDT="&dt"dt, 
  KeepVars=Key Key2 filename directory grid_sub_directory grid_sub_Filename short_Filename extension group permissions username 
           SIZE_BYTES size_kb size_mb size_gb DTTM_CREATE DTTM_MODIFIED  DAYS_SINCE_ACCESS Valid_From Valid_To Load_DT,
  UpdateType=DELTA);

/*Exract the current records as a test. It should match the base table if using the load date and the open*/
/*value marker of 31DEC9999*/
  proc sql;
  create table test as 
  select * from
  scd_load.unix_file_list_full_dh
  where datepart(valid_from) <="20JAN2021"d and datepart(valid_to) ="31Dec9999"d;
  quit;