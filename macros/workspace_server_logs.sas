/*************************************************************************************************************/
/*	MACROS:																									 */
/*  %GETFILELIST.SAS																						 */
/*  %GET_OBSCNT.SAS																							 */
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
/*  EMPTY_FILES = This flag allows workspace server logs which have no records to be printed to the final	 */
/*  table. The default is set to N but when Y is entered the results appear in the dataset. This can be used */
/*  to highlight session which have not processed any data. Check any XML logger filters which are in place  */
/* --------------------------------------------------------------------------------------------------------- */
/*%let macro_location=C:\temp\GIT\SAS-Code\macros;*/
/*%include 'C:\temp\GIT\SAS-Code\macros\clean_up.sas';*/
/*%include "'&macro_location\get_obscnt.sas'";*/
/*%include "'&macro_location\getfilelist.sas'";*/
%macro workspace_Server_logs(outtbl=,history=,config_location=,series=1,empty_files=N);
/*============================================================================================================*/
/* OUT TABLE NAME CHECK					                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* If the outtbl value has not been set then the process will use DATA_AUDIT_FINAL as the table name. It	  */
/* performs a length check on the name and when 0 it takes this as no named has been provided to override the */
/* default																									  */
/*------------------------------------------------------------------------------------------------------------*/
%if %length(&outtbl)=0 %then
	%do;
		%let outtbl=data_audit_final;
	%end;
%else;
%do;
	%put Using &outtbl as set in the macro;
%end;
%if /*&series=1 and */%sysfunc(exist(&outtbl._&series.)) %then %do;
  proc delete data=&outtbl._&series.; run;
%end;
/*============================================================================================================*/
/* ENVIRONMENT CHECK					                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will use the automatic system variable of SYSCCP to check the operating system where the      */
/* where the code is running. If the value is WIN (Windows) then it will set a backslash (\) or forward		  */
/* slash (/). This is then used to break up the string.														  */
/* SAS SUPPORT																							      */
/* https://support.sas.com/documentation/cdl/en/mcrolref/61885/HTML/default/viewer.htm#z3514sysscp.htm 		  */
/*------------------------------------------------------------------------------------------------------------*/
%global os_set_delim;

%if &SYSSCP=WIN %then
	%do;
%put OS=&SYSSCP SO SETTING THE STRING SEPERATOR TO \;
		%let os_set_delim=\;
		%goto end_os_step;
	%end;
%else;
%do;
%put OS=&SYSSCP SO SETTING THE STRING SEPERATOR TO /;
	%let os_set_delim=/;
%end;

%end_os_step:;

/*============================================================================================================*/
/* HISTORY REQUIREMENT					                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This will allow a variable to be passed to limit the amount of files being read. If 5 is passed then only  */
/* the files which are present for the last 5 days will be used. If no value is present this section will be  */
/* skipped and all files present in the log location will be used											  */
/*------------------------------------------------------------------------------------------------------------*/
%if &history >=. %then 
%do;
%put HISTORY FLAG SET TO &history;
	data _null_;
		call symput("dt_hist",PUT(intnx('day',today(),-&history),date9.));
	run;
	%put NOTE: FILES PRODUCED WHICH ARE GREATER THAN OR EQUAL TO &dt_hist WILL BE USED;
%end;
%else %do;
%put NOTE: HISTORY FLAG NOT SET;
%put NOTE: ALL FILES WILL BE READ IN %sysfunc(getoption(SASINITIALFOLDER))\WorkspaceServer\AuditLogs ;

%end;
/*============================================================================================================*/
/* GET FILE LIST						                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will use the %getfilelist macro to obtain a list of all file in a certian location. The    	  */
/* process will set the location useing the SASINITIALFOLDER option and then the default log location as 	  */
/* set in the LOGCONFIG.XML. 																			  	  */
/*------------------------------------------------------------------------------------------------------------*/

/*Read in a list of the logs to extract information from*/
%if %length(&config_location)>0 %then %do;
%getfilelist(
	Path=&config_location,
	Table=work.workspace_logs,
	Typefilter=log
	);
	%end;
%if %length(&config_location)=0 %then %do;
%getfilelist(
	Path=%sysfunc(getoption(SASINITIALFOLDER))&os_set_delim.WorkspaceServer&os_set_delim.AuditLogs,
	Table=work.workspace_logs,
	Typefilter=log
	);
%end;
/*	Date*/
/*------------------------------------------------------------------------------------------------------------*/
/* SUB STEP	1: CHECK HISTORY																				  */
/*------------------------------------------------------------------------------------------------------------*/
/* If the history macro has not been set then work.workspace_logs is read to get the minimum date. This allow */
/* all files in the log location to be read.																  */
/*------------------------------------------------------------------------------------------------------------*/
%if %eval(&history+0) = 0 %then
	%do;

		proc sql;
			select min(datepart(created)) format=date9. into: dt_hist
				from workspace_logs;
		quit;

		%put &dt_hist.;
	%end;
/*------------------------------------------------------------------------------------------------------------*/
/* SUB STEP	2: SELECT INSCOPE DATA																			  */
/*------------------------------------------------------------------------------------------------------------*/
/* This step will select the required data depending on whether the history macro was changed. If nothing is  */
/* set then the default is to read everything. Additional criteria is applied to filter only logs with content*/
/* and those which are marked as "File". This avoids empty files and unexpected file extentions being read	  */
/*------------------------------------------------------------------------------------------------------------*/
data readlogs;
	set workspace_logs;
	where membername like 'data_audit%'
		and Filesize > 0 and datepart(created)>="&dt_hist."d and entrytype ="File";
run;

/*------------------------------------------------------------------------------------------------------------*/
/* SUB STEP	3: CHECK FOR ZERO OBSERVATIONS																	  */
/*------------------------------------------------------------------------------------------------------------*/
/* If work.readlogs contains no observations the process will exit the macro early and place a NOTE: into the */
/* log asking for the input data to be checked. 															  */
/*------------------------------------------------------------------------------------------------------------*/

%if %get_obscnt(readlogs) =0 %then
	%do;
		%put NOTE: NO OBSERVATIONS FOUND;
		%goto exit_now_no_obs;
	%end;
%else
	%do;
		%put NOTE: OBSERVATIONS = %get_obscnt(readlogs);
	%end;

/*------------------------------------------------------------------------------------------------------------*/
/* SUB STEP	4: MACRO VARIABLE CREATION																		  */
/*------------------------------------------------------------------------------------------------------------*/
/* Set the macro variables for usage in the loop. The variable will contain the full path to the file. It is  */
/* used on the infile statement.																			  */
/*------------------------------------------------------------------------------------------------------------*/

proc sql noprint;
	select fullname into:audit_load1 - 
		from readlogs;
quit;

/*============================================================================================================*/
/* READ WORKSPACE LOG LOOP				                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will now read in the data from the various logs and then combine into one final table		  */
/*------------------------------------------------------------------------------------------------------------*/
	%do i=1 %to %get_obscnt(readlogs);
		data _audit_data_log&i.;
/*------------------------------------------------------------------------------------------------------------*/
/* Set the length, format and label of the required variables												  */
/*------------------------------------------------------------------------------------------------------------*/
			attrib  Hostname  length=$100  label='Hostname'
					DateTime  length=$100  label='Session Date Time Char'
					DTTM length=8. format=datetime20. label='Date Time Numeric'
					date length=8. format=date9. label='Date'
					time length=8. format=time10. label='Time'
					Userid  length=$50  label='User ID'
					Action  length=$50  label='Dataset Action'
					Status  length=$50  label='Status'
					Libref  length=$50  label='Libref'
					Engine  length=$50  label='SAS Engine'
					Member  length=$50  label='Member Name'
					MemberType  length=$50  label='Member Type'
					Openmode  length=$50  label='Open Mode'
					Path  length=$200  label='Path'
					Message  length=$100  label='Message'
					fullpath  length=$200  label='Full Path'
					logfile  length=$200  label='Log File'
					logname  length=$100  label='Batch Log Name'
					sysin  length=$100  label='Batch Code Name'
					PID length=4. label='Process Identifier'
					returncode length=4. label='Return Code';
/*------------------------------------------------------------------------------------------------------------*/
/* EMPTY FILES																								  */
/*------------------------------------------------------------------------------------------------------------*/
/* Conditional logic to allow a record to be printed to the file for workspace logs which contain no ouptut.  */
/* This flag can be used when you want to check session which have done no processing. You woudl need to check*/
/* what is present in the XML logger filters sessions. If WORK is filtered out then it may appear that no	  */
/* activity occured but it was the filter stopping the recording.											  */
/*------------------------------------------------------------------------------------------------------------*/
			%if &empty_files=Y %then %do;
			if (eof and _N_=1) then do;
			Hostname="EMPTY_FILE";
			date=input(scan("&&audit_load&i.",-3,"_"),yymmdd10.);
			logfile="&&audit_load&i.";
			PID=scan(scan("&&audit_load&i.",-1,"_"),1);
			output ;
			end;
			%end;
/*------------------------------------------------------------------------------------------------------------*/
/* INFILE STATEMENT																							  */
/*------------------------------------------------------------------------------------------------------------*/
/* Set the location to the log to read and start on the second line so that the labels are ignored			  */
/*------------------------------------------------------------------------------------------------------------*/
			infile "&&audit_load&i." dlm="|" missover firstobs=2 end=eof;
			input Hostname DateTime Userid Action Status Libref Engine Member MemberType Openmode Path;
/*------------------------------------------------------------------------------------------------------------*/
/* DATES																									  */
/*------------------------------------------------------------------------------------------------------------*/
/* Convert VARCHAR26 system datetimes to ones that SAS understand using E8601DT23.3			  				  */
/*------------------------------------------------------------------------------------------------------------*/
			dttm = input(scan(_infile_,2,'|'),e8601dt23.3);
			date = datepart(input(scan(_infile_,2,'|'),e8601dt23.3));
			time = timepart(input(scan(_infile_,2,'|'),e8601dt23.3));
/*------------------------------------------------------------------------------------------------------------*/
/* FULLPATH																									  */
/*------------------------------------------------------------------------------------------------------------*/
/* Create the full path to the SAS datasets used in the process								  				  */
/*------------------------------------------------------------------------------------------------------------*/
			fullpath=trim(right(scan(_infile_,11,'|')))||("&os_set_delim")||trim(left(scan(_infile_,8,"|")))||".sas7bdat";
/*------------------------------------------------------------------------------------------------------------*/
/* ERROR MESSAGE																							  */
/*------------------------------------------------------------------------------------------------------------*/
/* Error message is the code failed. 0 will return no message								  				  */
/*------------------------------------------------------------------------------------------------------------*/
			message=scan(_infile_,13,"|");
/*------------------------------------------------------------------------------------------------------------*/
/* LOG FILE LOCATION																						  */
/*------------------------------------------------------------------------------------------------------------*/
/* Location of the log file being read														  				  */
/*------------------------------------------------------------------------------------------------------------*/
			logfile="&&audit_load&i.";
/*------------------------------------------------------------------------------------------------------------*/
/* PROCESS ID																								  */
/*------------------------------------------------------------------------------------------------------------*/
/* Extract the process ID from the string. Check in the XML how the string is created. If this variable is	  */
/* is missing then it may be that the file creation string contains more information and you may need to 	  */
/* adjust the number of underscores (_) on the scan function											      */
/*------------------------------------------------------------------------------------------------------------*/
/*			PID=input(tranwrd(scan("&&audit_load&i.",7,"_"),".log"," "),8.);*/
			PID=scan(scan("&&audit_load&i.",-1,"_"),1);
/*------------------------------------------------------------------------------------------------------------*/
/* RETURN CODE																								  */
/*------------------------------------------------------------------------------------------------------------*/
/* Anything greater than 0 means the step failed and the message column will be populated	  				  */
/*------------------------------------------------------------------------------------------------------------*/
			returncode=input(scan(_infile_,12,"|"),8.);
/*------------------------------------------------------------------------------------------------------------*/
/* BATCH VARIABLES																							  */
/*------------------------------------------------------------------------------------------------------------*/
/* If the process has been submitted in batch then -log and -sysin have been used and the information 		  */
/* recorded in thje log output. Interactive session will be missing										      */
/*------------------------------------------------------------------------------------------------------------*/
			logname=scan(_infile_,21,"|");
			sysin=scan(_infile_,22,"|");
			output;
		run;

/*	%end;*/

/*============================================================================================================*/
/* STACKED FINAL TABLE					                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* All of the individual datasets will now be stacked into one final table as set by the OUTTBL variable	  */
/*------------------------------------------------------------------------------------------------------------*/
	/*Combine all temporary files into a final table*/
/*	data &outtbl._&series.;*/
/*		set _audit_data:;*/
/*	run;*/
%if %sysfunc(exist(&outtbl._&series.)) %then
	%do;

proc append data=_audit_data_log&i. base=&outtbl._&series.;
run;
	%end;
%else
	%do;

	data &outtbl._&series.;
		set _audit_data_log&i.;
	run;		

	%end;
/*Delete Temp Tables*/
%clean_up(_audit_data_log&i.);
	%end;
/*============================================================================================================*/
/* CONDITIONAL EXIT: EXIT_NOW_NO_OBS	                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* If "SUB STEP	3: CHECK FOR ZERO OBSERVATIONS"	detects no observations it will gracefully exit the process at*/
/* this line.																								  */
/*------------------------------------------------------------------------------------------------------------*/

/*============================================================================================================*/
/* CLEAN UP								                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* The final step in the macro is to clean up any of the temporary tables created. Warning may be generated	  */
/* if the macro exits early. Check the log, code comments and usage guide to resolve before submitting again  */
/*------------------------------------------------------------------------------------------------------------*/
proc datasets lib=work nolist;
/*	delete _audit_data:;*/
	delete workspace_logs;
	delete readlogs;
run;
%exit_now_no_obs:
%put NOTE: PROCESSING HAS CONDITIONALLY STOPPED DUE TO ZERO OBSERVATIONS DETECTED;
%put NOTE: PLEASE CHECK WORK.READLOGS TO RESOLVE THE ISSUE AND THEN RESUBMIT;
%mend;
/*%workspace_server_logs;*/
/*%workspace_server_logs(series=2,config_location=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\AuditLogs\old);*/
/*proc sql;*/
/*create table pid_miss as*/
/*select * from readlogs*/
/*where membername="data_audit_sukgeb_local@sukgeb_20200915_sukgeb_22792.log";*/
/*quit;*/
/*data_audit_sukgeb_local@sukgeb_20200710_sukgeb_23492.log*/
/*data_audit_sassrv@sukgeb_20200715_sukgeb_25452.log*/
/*%workspace_server_logs(outtbl=george);*/
/*%workspace_server_logs(series=2);*/
/*%workspace_server_logs(series=2,config_location=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\AuditLogs\old);*/
/*%workspace_server_logs(series=3,config_location=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\AuditLogs\temp);*/
/*%workspace_server_logs(series=3,config_location=C:\SAS\Config\Lev1\SASApp\ConnectServer\AuditLogs);*/







