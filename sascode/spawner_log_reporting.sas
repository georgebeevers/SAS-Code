/*************************************************************************************************************/
/*  PROGRAM NAME: SPAWNER_LOG_REPORTING.SAS  	 	                                  						 */
/*  DATE CREATED: 16/04/2021                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION:																							 */
/*  MACRO TO READ IN OBJECT SPAWNER AND CONNECT SPAWNER LOGS SO THAT THE NUMBER OF APPLICATIONS (EG,EM, DIS  */
/*  AND BASE SAS) CAN BE ANALYSED																			 */
/*  INPUTS:								  |              					                        		 */
/*	OBJECT SPAWNER = {SAS CONFIG LOG\Config\Lev{1-X}\SASApp\OBJECTSPAWNER\Logs\								 */
/*	CONNECT SPAWNER = {SAS CONFIG LOG\Config\Lev{1-X}\SASApp\CONNECTSPAWNER\Logs\							 */
/*  OUTPUTS:                                                                       							 */
/*  DEFAULT = WORK.SAS_APPLICATIONS_USED.SAS7BDAT															 */
/*																											 */
/*	MACROS:																									 */
/*  %GETFILELIST.SAS																						 */
/*  %GET_OBSCNT.SAS																							 */
/*  %CLEAN_UP.SAS																							 */
/* --------------------------------------------------------------------------------------------------------- */
/*  MACRO USAGE			                                                         							 */
/*  The macro can be executed without any variables being passed. In doign this all logs would be read and   */
/*  and the output saved in work.																			 */
/*  OUTTBL = Enter a name for the final table																 */
/*  HISTORY = Enter a numeric value for the number of days history you want to read (5 = last 5 days)		 */
/*  CONFIG_LOCATION = Enter the full path to the workspace server logs to be read. This can be used when	 */
/*  testing the setup or when log managemen is in place.													 */
/*  SERIES = Set the series to increment depending on the number of files to read in. Each file will have    */
/*  _{1-9} assigned to the end. Merging can then be done quickly and easily without multiple file names		 */
/* --------------------------------------------------------------------------------------------------------- */
%include 'C:\temp\GIT\SAS-Code\macros\get_obscnt.sas';
%include 'C:\temp\GIT\SAS-Code\macros\clean_up.sas';
%include 'C:\temp\GIT\SAS-Code\macros\getfilelist.sas';
%include 'C:\temp\GIT\SAS-Code\macros\connect_spawn_log_read.sas';
%include 'C:\temp\GIT\SAS-Code\macros\object_spawner_log_read.sas';
%include 'C:\temp\GIT\SAS-Code\macros\sas_application_reporting.sas';
/*============================================================================================================*/
/* ASSIGN LIBNAMES					                                    								  	  */
/*============================================================================================================*/
libname m_va0 'C:\temp\SAS_Data\server_metrics\m_va0';

/*============================================================================================================*/
/* OBJECT SPAWNER APPLICATIONS		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Obtain application connections via the object spawner server. EG, EM, DIS etc							  */
/* If the logs exist in another location then use the macro parameters to control the results.				  */
/*------------------------------------------------------------------------------------------------------------*/
%object_spawner_logs;
%object_spawner_logs(series=2, config_location=C:\SAS\Config\Lev1\ObjectSpawner\Logs\temp);
%object_spawner_logs(series=3, config_location=C:\SAS\Config\Lev1\ObjectSpawner\Logs\parse);
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
%connect_spawn_log_read;
%connect_spawn_log_read(series=2,config_location=C:\SAS\Config\Lev1\ConnectSpawner\Logs\temp);
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
data m_va0.sas_applications_used;
length hostname $100;
/*Amend the filenames if they have been changed*/
set object_spawner_final connect_spawner_final;
if hostname ="" then hostname=%sysfunc(dequote("&_SASHOSTNAME"));
run;

%clean_up(object_spawner_final);
%clean_up(connect_spawner_final);

/*============================================================================================================*/
/* GENERATE REPORTS					                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Generate some example reports. More reports can be added to %sas_application_reporting macro				  */
/*------------------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------------------*/
/* TABLE 1 - TOP APPLICATION LAUNCHERS SINCE X DATE															  */
/*------------------------------------------------------------------------------------------------------------*/
/* Table showing the users who have launched more than 5 applications in a day since a particular date	      */
/*------------------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------------------*/
/* TABLE 2 - TOP APPLICATION LAUNCHERS TODAY																  */
/*------------------------------------------------------------------------------------------------------------*/
/* Table showing the users who have launched more than 5 applications today						 		      */
/*------------------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------------------*/
/* CHART 1 - APPLICATION USAGE OVER TIME																	  */
/*------------------------------------------------------------------------------------------------------------*/
/* Chart the usage of SAS applications over a period of time. The data will be displayed as a stacked bar     */
/* graph.																									  */
/*------------------------------------------------------------------------------------------------------------*/
/*------------------------------------------------------------------------------------------------------------*/
/* CHART 2 - APPLICATION USAGE PIE CHART																	  */
/*------------------------------------------------------------------------------------------------------------*/
/* Chart the usage of SAS applications over a period of time. The data will be displayed as a pie chart	      */
/*------------------------------------------------------------------------------------------------------------*/
/*options symbolgen mlogic mprint;*/
%sas_application_reporting(intbl=m_va0.sas_applications_used);
%sas_application_reporting(user=sassrv@sukgeb,history=360);
%sas_application_reporting(user=sukgeb_local@sukgeb);


/*NOTE - merge with workspace server logs to get a view on how long the session was open for.*/
/*No datasets would represent no activity*/
/*start of data to end of data would represent the activity*/
/*#datasets read*/
/*#datsets created*/




