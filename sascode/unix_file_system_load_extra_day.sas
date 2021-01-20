/*Fake data load - test an SCD Load*/

/*Load the same data as the base table. If you have new data then use that*/


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
/*Make the change obvious whilst testing*/
proc sql;
update unix_file_list_snapshot
set size_bytes =99999999
where filename="/mnt/c/temp/SAS_Data/audit/00_control_data/business_units.csv";
run;

/*Add the load keys*/
data unix_file_list_snapshot_key;
set unix_file_list_snapshot;
key + 1;
key2 = key * 100;
run;

/*Manually change the dates*/
/*This sets to the next day*/

%let dt=21JAN2021:8:36:09;
%let valfromdt=21JAN2021:00:00:00;

/*Load the new data*/

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