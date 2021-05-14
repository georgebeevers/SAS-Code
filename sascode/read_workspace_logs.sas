/*************************************************************************************************************/
/*  PROGRAM NAME: WORKSPACE_SERVER_READ.SAS  	                                    						 */
/*  DATE CREATED: 16/04/2021                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION:																							 */
/*  MACRO TO READ IN WORKSPACE LOGS WHICH HAVE BEEN CONFIGURED IN THE WORKSPACE LOGGER XML					 */
/*  				   																						 */
/*  INPUTS:								  |              					                        		 */
/*	LOGS HELD IN {SAS CONFIG LOG\Config\Lev{1-X}\SASApp\WorkspaceServer\AuditLogs\							 */
/*																											 */
/*  OUTPUTS:                                                                       							 */
/*  DEFAULT = WORK.DATA_AUDIT_FINAL.SAS7BDAT																 */
/*																											 */
/*	MACROS:																									 */
/*  %GETFILELIST.SAS																						 */
/*  %GET_OBSCNT.SAS																							 */
/*  %CLEAN_UP.SAS																							 */
/*  %WORKSPACE_SERVER_LOGS.SAS																				 */
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

/*============================================================================================================*/
/* SET THE MACRO LOCATION			                                    								  	  */
/*============================================================================================================*/
%let macro_location=C:\temp\GIT\SAS-Code\macros;
/*============================================================================================================*/
/* INLCUDE THE REQUIRED MACROS		                                    								  	  */
/*============================================================================================================*/
/*options symbolgen mlogic mprint;*/
%include "'&macro_location\get_obscnt.sas'";
%include "'&macro_location\clean_up.sas'";
%include "'&macro_location\getfilelist.sas'";
%include "'&macro_location\workspace_server_logs.sas'";

/*============================================================================================================*/
/* 1. SIMPLE EXECUTION - ALL DEFFAULTS                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* HISTORY REQUIREMENTS ARE SET TO EVERYTHING ADN THE TABLE IS NAMED DATA_AUDIT_FINAL WHICH IS THE DEFAULT.	  */
/* READS CONTENT HELD IN THE WORKSPACE\AUDILOGS LOCATION													  */
/*------------------------------------------------------------------------------------------------------------*/
%workspace_server_logs(empty_files=Y);
%workspace_server_logs(series=2,config_location=C:\SAS\Config\Lev1\SASApp\ConnectServer\AuditLogs,empty_files=Y);
%workspace_server_logs(series=3,config_location=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\AuditLogs\old,empty_files=Y);
%workspace_server_logs(series=4,config_location=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\AuditLogs\sub,empty_files=Y);
data data_audit;
set data_audit_final:;
run;
%clean_up(data_audit_final_1);
%clean_up(data_audit_final_2);
%clean_up(data_audit_final_3);
%clean_up(data_audit_final_4);
/*============================================================================================================*/
/* 2. TABLE NAME WITH ALL HISOTRY		                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* HISTORY REQUIREMENTS ARE SET TO EVERYTHING ADN THE TABLE NAME IS CHANGED FROM THE DEFAULT WORK LOCATION	  */
/* READS CONTENT HELD IN THE WORKSPACE\AUDILOGS LOCATION													  */
/*------------------------------------------------------------------------------------------------------------*/
libname mine 'c:\temp';
%workspace_server_logs(outtbl=mine.mydata);
/*============================================================================================================*/
/* 3. HISTORY CHANGE					                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* HISTORY REQUIREMENTS ARE SET TO READ ALL LOGS CREATED IN THE LAST X DAYS WITH THE DEFAULT TABLE NAME		  */
/* READS CONTENT HELD IN THE WORKSPACE\AUDILOGS LOCATION													  */
/*------------------------------------------------------------------------------------------------------------*/
%workspace_server_logs(history=1);
/*============================================================================================================*/
/* 4. NAME AND HISTORY CHANGE			                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* HISTORY REQUIREMENTS ARE SET TO READ ALL LOGS CREATED IN THE LAST X DAYS AND CHANGE THE FILE NAME		  */
/* READS CONTENT HELD IN THE WORKSPACE\AUDILOGS LOCATION													  */
/*------------------------------------------------------------------------------------------------------------*/
%workspace_Server_logs(outtbl=george_ws,history=1);
/*============================================================================================================*/
/* 5. CONFIG LOCATION CHANGE			                                   								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* USE THIS OPTION TO POINT TO A DAILY SNAPSHOT OR TESTING LOCATION DURING THE SETUP PHASE					  */
/*  																										  */
/*------------------------------------------------------------------------------------------------------------*/
%workspace_server_logs(config_location=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\AuditLogs\temp);
