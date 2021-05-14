/*TESTING ONLY OPTIONS*/
/*options symbolgen mprint mlogic;*/
/*************************************************************************************************************/
/*  PROGRAM NAME: CREATE_REPORT_TABLE.SAS      	                                    						 */
/*  DATE CREATED: 17/01/2020                                                      							 */
/*  AUTHOR: GEORGE BEEVERS						                                                 			 */
/*  PURPOSE: THIS CODE WILL CREATE A REPORT TABLE WHICH INCLUDES DORMANCY MARKER, NON SAS OR SAS FILE MARKER,*/
/*  COMPRESSION MARKER AND ADD DATA FROM A LOOKUP ON MOUNT OWNERS										     */
/*  				   																						 */
/*  INPUTS:								  |              					                        		 */
/*		MYDATA.UNIX_FILE_LIST_FULL (CREATE_FILE_LIST_FIN.SAS)												 */
/*		GROUP_LKUP.TXT																						 */
/*  OUTPUTS:                                                                       							 */
/*  	WORK.SNAPSHOT_LIST_FIN																				 */
/* --------------------------------------------------------------------------------------------------------- */
/*  Macros: CREATE_REPORT_TABLE                                                    							 */
/*                                                                                 							 */
/* --------------------------------------------------------------------------------------------------------- */

/*============================================================================================================*/
/* MACRO START: CREATE REPORT TABLE WITH MARKER                                								  */
/*============================================================================================================*/

/*------------------------------------------------------------------------------------------------------------*/
/* MACRO PARAMETERS                                                        								      */
/* 1. DATE = the reporting date to be extracted														  		  */
/* 2. DORMANT FLAG = The boundary for live 'vs' dormant files.										   		  */
/* 3. LKUP_PATH = Windows of server location of the lookup file				 								  */
/*		a. GROUP - The owning group (e.g SASPRODFINANA = FINANCE ANALYTICS)									  */ 
/*		b. FUNCTION - The real name of the owning group (e.g SASPRODFINANA = FINANCE ANALYTICS)				  */
/*		c. PRIMARY_OWNER - Group primary owner																  */
/*		d. SECONDARY_OWNER - Group secondary owner															  */
/*		e. MOUNTED_ON - Physical mount point																  */
/*		f. DIR_MOUNT - Directory mount point. Used when many teams utilise one mount point as they can be 	  */
/*		collected together and matched back to a mount.														  */
/*------------------------------------------------------------------------------------------------------------*/

/*%let date=07JUL2020;*/
%let dormant_flag =90;
%let lkup_path=C:\temp\SAS_Data\Lookups;

  proc sql;
  create table snapshot_sample as 
  select * from
  scd_load.unix_file_list_full_dh
  where datepart(valid_from) <="04FEB2021"d and datepart(valid_to) ="31Dec9999"d;
  quit;

%macro create_report_table();
proc sql;
	create table snapshot_list_fin as 
		select d_Start
			,filename
			,directory
			,short_filename
			,extension
			,group
			,username
			,size_mb
			,size_gb
			,dttm_create
			,dttm_modified
			,intck('day',datepart(dttm_modified),today()) as days_since_access
			,
		(case 
			when intck('day',datepart(dttm_modified),today()) >=&dormant_flag. then "DORMANT" 
			else "LIVE" 
		end)
	as DORMANCY_MARKER
		,
	(case 
		when intck('day',datepart(dttm_modified),today()) between 0 and 30 then "0-30 Days" 
		when intck('day',datepart(dttm_modified),today()) between 30 and 60 then "30-60 Days" 
		when intck('day',datepart(dttm_modified),today()) between 60 and 90 then "60-90 Days"
		when intck('day',datepart(dttm_modified),today()) between 60 and 90 then "60-90 Days"  
		else "90+ Days" 
	end)
as DORMANCY_BAND
	,
(case 
	when extension in ('LOG','SAS','CFG','EGP','FMT','GZ','SAS7BDAT','ZIP','SAS7BNDX','SAS7BVEW','SAS7BCAT','BZ2','Z','DONE','SPK','OK','TRIGGER','SAS7BITM','LCK') then "SAS FILE" 
	else "NON SAS" 
end)
as SAS_FILE_MARKER
,
(case 
when extension in ('GZ','ZIP','BZ2','Z') then "COMPRESSED" 
else "NO COMPRESSION" 
end)
as COMPRESS_MARKER
,
(case 
when size_gb>=100 then "LARGE" 
else "OK" 
end)
as SIZE_MARKER
	," " as Mounted_on length=200
				," " as Primary_owner length=50
				," " as Secondary_owner length=50
				," " as Function length=50
from unix_file_list_full
/*where d_start ="&date."d;*/
;quit;
/*%mend;*/
/**/
/*%create_report_table;*/
data group_lkup;
	length group $24 Function $24 primary_owner $30 secondary_owner $30  mounted_on $100 dir_mount $100;
	infile "&lkup_path.\group_lkup.txt" dlm=',' missover lrecl=1024;
	input group Function primary_owner secondary_owner mounted_on dir_mount;
run;

	proc sql noprint;
		select count(*) into: max_num trimmed 
			from group_lkup;
	quit;

	proc sql noprint;
		select mounted_on, dir_mount, primary_owner,secondary_owner, function
			into: mounted_on1 - :mounted_on&max_num.
			,:dir_mount1 - :dir_mount&max_num.
			,:primary_owner1 - :primary_owner&max_num. 
			,:secondary_owner1 - :secondary_owner&max_num. 
			,:function1 - :function&max_num.       
		from group_lkup;
	quit;


	%do i=1 %to &max_num.;
		%put &&mounted_on&i.;
		%put &&dir_mount&i.;

		proc sql;
			update snapshot_list_fin
				set mounted_on ="&&mounted_on&i."
					where directory contains ("&&dir_mount&i.");
			update snapshot_list_fin
				set primary_owner ="&&primary_owner&i."
					where directory contains ("&&dir_mount&i.");
			update snapshot_list_fin
				set secondary_owner ="&&secondary_owner&i."
					where directory contains ("&&dir_mount&i.");
			update snapshot_list_fin
				set function ="&&function&i."
					where directory contains ("&&dir_mount&i.");
		quit;

	%end;
%mend;

%create_report_table;
/*Load to VA Library*/
libname m_hsbc0 "C:\temp\SAS_Data\M_HSBC";
proc sql;
create table m_hsbc0.snapshot_list_fin as
select * from snapshot_list_fin;
quit;

/*============================================================================================================*/
/* MACRO END: CREATE REPORT TABLE WITH MARKER                                								  */
/*============================================================================================================*/
/*proc sql;*/
/*create table checks as*/
/*select */
/*group*/
/*,Primary_owner*/
/*,secondary_owner*/
/*,count(*) as count*/
/*from snapshot_list_fin*/
/*group by 1,2,3;*/
/*quit;*/
/**/
/**/
/*proc sql;*/
/*create table usage as*/
/*select days_since_Access*/
/*,count(*) as num_files*/
/*,sum(size_gb) as GB_Data*/
/*from snapshot_list_fin*/
/*group by 1;*/
/*quit;*/


