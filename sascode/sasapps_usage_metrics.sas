/*************************************************************************************************************/
/*  PROGRAM NAME: SASAPPS_USAGE_METRICS.SAS    	                                    						 */
/*  DATE CREATED: 			                                                      							 */
/*  AUTHOR:  																								 */
/*  DESCRIPTION:																							 */
/*  ALLOWS ARM LOG INFORMATION FOR IO COUNT, USER CPU, SYSTEM CPU, MEMORY AND SESSION ELAPSED TIME TO BE 	 */
/*  ADDED TO THE OBJECT SPAWNER INFORMATION																	 */
/*  INPUTS:								  |              					                        		 */
/*	VARIOUS AS PER THE MACRO DEFAULT OR PARAMETER INPUTS													 */
/*																											 */
/*  OUTPUTS:                                                                       							 */
/*  M_VA0.SAS_APPLICATION_STATS																				 */
/*																											 */
/*	MACROS																									 */
/*  GET_OBSCNT.SAS												 	    									 */
/*  CLEAN_UP.SAS																							 */
/*  GETFILELIST.SAS																							 */
/*  CONNECT_SPAWN_LOG_READ.SAS																				 */
/*  OBJECT_SPAWNER_LOG_READ.SAS																				 */
/*  GET_ARM_LOG_STATS.SAS																					 */
/* --------------------------------------------------------------------------------------------------------- */
/*  VERSION CONTROL		                                                         							 */
/*                                                                                 							 */
/* --------------------------------------------------------------------------------------------------------- */
/*Remove once added to a central macro and sascode area*/
%include 'C:\temp\GIT\SAS-Code\macros\get_obscnt.sas';
%include 'C:\temp\GIT\SAS-Code\macros\clean_up.sas';
%include 'C:\temp\GIT\SAS-Code\macros\getfilelist.sas';
%include 'C:\temp\GIT\SAS-Code\macros\connect_spawn_log_read.sas';
%include 'C:\temp\GIT\SAS-Code\macros\object_spawner_log_read.sas';
/*%include 'C:\temp\GIT\SAS-Code\macros\workspace_server_logs.sas';*/
/*%include 'C:\temp\GIT\SAS-Code\macros\sas_application_reporting.sas';*/
%include 'C:\temp\GIT\SAS-Code\macros\get_arm_log_stats.sas';

libname m_va0 'C:\temp\SAS_Data\server_metrics\m_va0';

/*============================================================================================================*/
/* OBJECT SPAWNER APPLICATIONS		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Obtain application connections via the object spawner server. EG, EM, DIS etc							  */
/* If the logs exist in another location then use the macro parameters to control the results.				  */
/*------------------------------------------------------------------------------------------------------------*/
%object_spawner_logs(history=90);
%object_spawner_logs(series=2, config_location=C:\SAS\Config\Lev1\ObjectSpawner\Logs\temp,history=90);
%object_spawner_logs(series=3, config_location=C:\SAS\Config\Lev1\ObjectSpawner\Logs\parse,history=90);
data object_spawner_final;
set object_spawner_final_:;
run;
%clean_up(object_spawner_final_1);
%clean_up(object_spawner_final_2);
%clean_up(object_spawner_final_3);
/*============================================================================================================*/
/* CONNECT SERVER APPLICATIONS		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Obtain BASE SAS connections																				  */
/* If the logs exist in another location then use the macro parameters to control the results.				  */
/*------------------------------------------------------------------------------------------------------------*/
%connect_spawn_log_read(history=90);
%connect_spawn_log_read(series=2,config_location=C:\SAS\Config\Lev1\ConnectSpawner\Logs\temp,history=90);
data connect_spawner_final;
set connect_spawner_:;
run;
%clean_up(connect_spawner_final_1);
%clean_up(connect_spawner_final_2);
/*============================================================================================================*/
/* STACKED APPLICATION TABLE		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create a single table with all applications present. The connect server will capture the hostname when the */
/* session is established. The object server does not hold this information so when its not present the 	  */
/* global hostname variable is used																			  */
/*------------------------------------------------------------------------------------------------------------*/
data sas_applications_used;
length hostname $100;
/*Amend the filenames if they have been changed*/
set object_spawner_final connect_spawner_final;
if hostname ="" then hostname=%sysfunc(dequote("&_SASHOSTNAME"));
run;

%clean_up(object_spawner_final);
%clean_up(connect_spawner_final);

/*============================================================================================================*/
/* ARM LOG STATS					                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Use the ARM log macro to obtain the metrics for each session. Metrics returns will be User CPU, System CPU,*/
/* IO Count, Memory Used, Session Time, Session Start and End Date											  */
/*------------------------------------------------------------------------------------------------------------*/

%get_arm_log_stats(history=90);
/*Connect server for Base Perf Stats*/
%get_arm_log_stats(series=2,config_location=C:\SAS\Config\Lev1\SASApp\ConnectServer\PerfLogs,history=90);
/*create a stack*/
data arm_stack;
set arm_:;
run;
%clean_up(arm_sessions_1);
%clean_up(arm_sessions_2);
/*============================================================================================================*/
/* APPLICATION AND ARM MERGE		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Join the application and metrics tables on the PID.														  */
/*------------------------------------------------------------------------------------------------------------*/
/*Allow only the last 90 days of data*/
data _null_;
	call symput("dt_hist",PUT(intnx('day',today(),-90),date9.));
run;

proc sql;
	create table m_VA0.sas_application_stats as
		select a.*
			,c.UserCPU_secs as UserCPU label="User CPU in Seconds"
			,c.systemcpu_secs as SystemCPU label="System CPU in Seconds"
			,c.sessiontime_mins as SessionTime label='Session Processing Time (MINS)'
			,case when c.sessiontime_mins <=5 then "L" 
					when c.sessiontime_mins >=400 then "H" 
					else "M" end as SessionTimeBand label='Banding Based on Session Open Time'
			,c.inittimestamp
			,c.endtimestamp
			,c.realtimeusedsession
			,c.memoryused
			,c.iocount
	/*,b.date as ws_Date*/
	from sas_applications_used as a
left outer join
arm_Stack as c
on a.PID=C.processID
and a.date=datepart(c.sessiondttm)
where a.date>="&dt_hist."d;
quit;

%clean_up(arm_Stack);
%clean_up(sas_applications_used);
