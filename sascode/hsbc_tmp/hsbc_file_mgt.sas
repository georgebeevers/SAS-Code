/*options obs=max;*/
/*/anenv/prd/cads/cads1/Control_M/baselusetest/Pre_dec_processing/old*/
/*%let main_path=C:\Users\sukgeb\OneDrive - SAS\Documents\1_Banking\1_HSBC\2021\Server Metrics & Monitoring\File Management;*/
/*%unix_file_list(local_path=&main_path.\sas_files_cads1_290121.txt,path=/anenv/prd/cads/cads1/,output=WORK.FILE_LIST_UNIX_BASE,atime=NO);*/
/*%unix_file_list(local_path=&main_path.\sas_files_lslu_cads1_290121.txt,path=/anenv/prd/cads/cads1/,output=WORK.FILE_LIST_UNIX_LSLU,atime=YES);*/
%include 'C:\temp\GIT\SAS-Code\macros\type2loader.sas';
%include 'C:\temp\GIT\SAS-Code\macros\get_unix_file_list_v2.sas';
%include 'C:\temp\GIT\SAS-Code\macros\clean_up.sas';

libname M_VA0 "C:\temp\SAS_Data\server_metrics\m_va0";
libname detail0 "C:\temp\SAS_Data\server_metrics\detail0";
/*============================================================================================================*/
/* LOAD BASE LISTINGS					                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will load the base files into a consolidated SAS table. If more than one file has been 		  */
/* produeced then the series needs to be added. More options can be viewed directly in the macro. This method */
/* reads in a series of flat files which have been created by a shell process. These files are held in the	  */
/* filepath location. Parameter one is path and this allows the full path to be split in the program. If 	  */
/* shell escape is possible (XMCD) then ssh=Y can be set as a parameter and the output would be piped directly*/
/* into SAS. Filepath woudl not be needed as a parameter.													  */
/*------------------------------------------------------------------------------------------------------------*/
%unix_file_list(/mnt/c/temp/,filepath=C:\temp\file_listing\sas_files_1.txt);
%unix_file_list(/mnt/c/temp/,filepath=C:\temp\file_listing\sas_files_2.txt,series=2);
%unix_file_list(/mnt/c/temp/,filepath=C:\temp\file_listing\sas_files_3.txt,series=3);

/*============================================================================================================*/
/* LOAD LSLU (ACCESS TIME) LISTINGS		                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will load the LSLU files into a consolidated SAS table. If more than one file has been 		  */
/* produeced then the series needs to be added. More options can be viewed directly in the macro. This method */
/* reads in a series of flat files which have been created by a shell process. These files are held in the	  */
/* filepath location. Parameter one is path and this allows the full path to be split in the program. If 	  */
/* shell escape is possible (XMCD) then ssh=Y can be set as a parameter and the output would be piped directly*/
/* into SAS. Filepath woudl not be needed as a parameter.													  */
/*------------------------------------------------------------------------------------------------------------*/
%unix_file_list(/mnt/c/temp/,filepath=C:\temp\file_listing\sas_files_lslu_1.txt,atime=Y);
%unix_file_list(/mnt/c/temp/,filepath=C:\temp\file_listing\sas_files_lslu_2.txt,atime=Y,series=2);
%unix_file_list(/mnt/c/temp/,filepath=C:\temp\file_listing\sas_files_lslu_3.txt,atime=Y,series=3);

/*============================================================================================================*/
/* MERGE THE TWO FILES					                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create a consolidated table which inlcudes the created and accessed date. If ATIME is not available then	  */
/* consider using the output from the workspace server data audit. This process captures the last accessed	  */
/* timestamp of all SAS files. ATIME can capture all file types.										      */
/* Snapshot data is loaded to a VA (Visual Analytics) holding folder where it could be loaded.				  */
/*------------------------------------------------------------------------------------------------------------*/
proc sql;
	create table M_VA0.unix_file_list_full as
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
%clean_up(file_list_unix_lslu);
%clean_up(file_list_unix_base);

/*============================================================================================================*/
/* HISTORY LOAD						                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will load the snapshot daily view into a history table. The data will be held as a dimension  */
/* hisotry table (DELTA) where only the records which have changed are updated. This makes it more efficient  */
/* to hold large volumes of slowly changing data.															  */
/*------------------------------------------------------------------------------------------------------------*/
/*%clean_up(detail0.unix_file_list_full_dh);*/

/*============================================================================================================*/
/* LOAD DATES						                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create the dates for the load																			  */
/* DT = Datetime of when the load is taking place (27APR2021:15:38:58)					 					  */
/* VALFROMDT = Valid from datetime which is set to midnight of the load datetime (27APR2021:00:00:00)		  */
/*------------------------------------------------------------------------------------------------------------*/
%let dt=%sysfunc(date(),date9.):%sysfunc(compress(%sysfunc(time(),time8.0)));
%let valfromdt=%sysfunc(date(),date9.):00:00:00;
%put &dt.;
%put &valfromdt.;

/*============================================================================================================*/
/* UNIQUE KEY						                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create a unique key on the file which will be used to manage the loads									  */
/*------------------------------------------------------------------------------------------------------------*/
data unix_file_list_snapshot_key;
	set M_VA0.unix_file_list_full;
	key + 1;
	key2 = key * 100;
run;

/*============================================================================================================*/
/* LOAD TO HISTORY TABLE			                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Load the snapshot to the history table																	  */
/* 1. COMPARE VALUES																						  */
/* If any of the following values change then the old record is closed and a new one opened. The values used  */
/* will detect for creation, deletion or modification of a file.											  */
/* FILENAME																									  */
/* SIZE_BYTES																								  */
/* DTTM_CREATE																								  */
/* DTTM_MODIFIED																							  */
/* 2. KEEP VARIABLES																						  */
/* This is where the required variables are set to be kept. Any listed variable here will be kept and this 	  */
/* process is listing all variables																			  */
/* 3. UPDATE TYPE																							  */
/* This is where DELTA or FULL can be set and this will either load the changed records or everything (FULL)  */
/*------------------------------------------------------------------------------------------------------------*/
%Type2Loader(
	TargetTable=detail0.unix_file_list_full_dh, 
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
  detail0.unix_file_list_full_dh
  where datepart(valid_from) <="28APR2021"d and datepart(valid_to) ="31Dec9999"d;
  quit;