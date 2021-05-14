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
/* --------------------------------------------------------------------------------------------------------- */
%macro connect_spawn_log_read(outtbl=,history=,config_location=,series=1);
%if &series=1 and %sysfunc(exist(&outtbl._&series.)) %then %do;
  proc delete data=&outtbl; run;
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
/* OBTAIN INITIALISATION FOLDER			                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Using the initialisation option as the base and then applying the OS set delimiter the correct folder	  */
/* for the logs can be automatically generated. Using the config_location option this default location can be */
/* changed. This will allow testing and setup to be easier.													  */
/*------------------------------------------------------------------------------------------------------------*/
data _null_;
	folder="%sysfunc(getoption(SASINITIALFOLDER))";
	CALL SCAN( "%sysfunc(getoption(SASINITIALFOLDER))", -2, last_pos, last_length, "&os_set_delim", 'l');
	call symput("sas_config",substrn( "%sysfunc(getoption(SASINITIALFOLDER))", 1, last_pos + last_length -1));
run;
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
%put NOTE: ALL FILES WILL BE READ IN %sysfunc(getoption(SASINITIALFOLDER))&os_set_delim.ConnectSpawner&os_set_delim.Logs ;

%end;

/*============================================================================================================*/
/* GET FILE LIST						                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will use the %getfilelist macro to obtain a list of all file in a certian location. The    	  */
/* process will set the location using the SASINITIALFOLDER option. This option can be used if a testing 	  */
/* lcoation or monthly snapshot location are being used to manage the logs								  	  */
/*------------------------------------------------------------------------------------------------------------*/
%if %length(&config_location)>0 %then
	%do;
		%getfilelist(
			Path=&config_location,
			Table=work._logs_connect,
			Typefilter=log
			);
	%end;

%if %length(&config_location)=0 %then
	%do;
		%getfilelist(
			Path=&sas_config.&os_set_delim.ConnectSpawner&os_set_delim.Logs,
			Table=work._logs_connect,
			Typefilter=log
			);
	%end;
/*------------------------------------------------------------------------------------------------------------*/
/* SUB STEP	1: CHECK HISTORY																				  */
/*------------------------------------------------------------------------------------------------------------*/
/* If the history macro has not been set then work.workspace_logs is read to get the minimum date. This allow */
/* all files in the log location to be read.																  */
/*------------------------------------------------------------------------------------------------------------*/
%if %eval(&history+0) = 0 %then
	%do;

		proc sql noprint;
			select min(datepart(created)) format=date9. into: dt_hist
				from _logs_connect;
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
	set _logs_connect;
	where Filesize > 0 and datepart(created)>="&dt_hist."d and entrytype ="File";
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
	select fullname 
		into:connect_log1 - 
	from readlogs;
quit;
/*============================================================================================================*/
/* READ CONNECT LOG LOOP				                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* This section will now read in the data from the various logs and then combine into one final table		  */
/*------------------------------------------------------------------------------------------------------------*/
%do i=1 %to %get_obscnt(readlogs);
data _connect_spawner_log&i.;
/*------------------------------------------------------------------------------------------------------------*/
/* Set the length, format and label of the required variables												  */
/*------------------------------------------------------------------------------------------------------------*/
attrib  
	application length=$30 label='Application'
	Hostname  length=$100  label='Hostname'
	DTTM length=8. format=datetime20. label='Date Time Numeric'
	date length=8. format=date9. label='Date'
	time length=8. format=time10. label='Time'
	Userid  length=$50  label='User ID'
	PID length=4. label='Process Identifier'
	logname  length=$100  label='Batch Log Name';
/*------------------------------------------------------------------------------------------------------------*/
/* INFILE STATEMENT																							  */
/*------------------------------------------------------------------------------------------------------------*/
/* Set the location to the log to read and start on the second line so that the labels are ignored			  */
/*------------------------------------------------------------------------------------------------------------*/
	infile "&&connect_log&i." dlm=":" missover firstobs=3;
	RETAIN application dttm date time PID logname userid hostname;
	input;
/*------------------------------------------------------------------------------------------------------------*/
/* APPLICATION																								  */
/*------------------------------------------------------------------------------------------------------------*/
/* Unlike the object spawner logs the application name for Base SAS is not captured. As all Base SAS can be   */
/* be identified by standard markers this will be set manually when the relevant criteria is met			  */  
/*------------------------------------------------------------------------------------------------------------*/
	application="BASE";
/*------------------------------------------------------------------------------------------------------------*/
/* LOGNAME																								  	  */
/*------------------------------------------------------------------------------------------------------------*/
/* Print from the looping macro																				  */
/*------------------------------------------------------------------------------------------------------------*/
	logname="&&connect_log&i.";
/*------------------------------------------------------------------------------------------------------------*/
/* FIND																										  */
/*------------------------------------------------------------------------------------------------------------*/
/* The loop will look for all connections which have "successfully authenticated" in the string. When this is */
/* found then the values extracted are retained. Only when a PID is present is the line output				  */  
/*------------------------------------------------------------------------------------------------------------*/
	if find(_infile_,"successfully authenticated") then
		do;
/*------------------------------------------------------------------------------------------------------------*/
/* DATES																									  */
/*------------------------------------------------------------------------------------------------------------*/
/* Convert VARCHAR26 system datetimes to ones that SAS understand using E8601DT23.3			  				  */
/*------------------------------------------------------------------------------------------------------------*/
	dttm = input(scan(_infile_,1,','),e8601dt23.3);
	date = datepart(input(scan(_infile_,1,'|'),e8601dt23.3));
	time = timepart(input(scan(_infile_,1,'|'),e8601dt23.3));
/*------------------------------------------------------------------------------------------------------------*/
/* USERID & HOSTNAME																						  */
/*------------------------------------------------------------------------------------------------------------*/
/* Extract userid and hostname from the string. In large installations there may be more than one server that */
/* that BASE SAS sessions are started. This will allow all to be captured.									  */
/*------------------------------------------------------------------------------------------------------------*/
	userid = compress(scan(_infile_,10," "),'"');
	hostname=scan(_infile_,12," ");
	end;
/*------------------------------------------------------------------------------------------------------------*/
/* PID																						  */
/*------------------------------------------------------------------------------------------------------------*/
/* Identify when a PID is present and then output the row. If not PID is present then the session has not	  */
/* started correctly on the server.																			  */
/*------------------------------------------------------------------------------------------------------------*/
	if find(_infile_,"PID") then
		do;
			PID=input(scan(_infile_,14),8.);
			output;
		end;
	run;

%end;
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
		%let outtbl=connect_spawner_final;
	%end;
%else;
%do;
	%put Using &outtbl as set in the macro;
%end;
/*============================================================================================================*/
/* STACKED FINAL TABLE					                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* All of the individual datasets will now be stacked into one final table as set by the OUTTBL variable	  */
/*------------------------------------------------------------------------------------------------------------*/
     data &outtbl._&series.;
           set _connect_spawner_log:;
     run;
/*============================================================================================================*/
/* CONDITIONAL EXIT: EXIT_NOW_NO_OBS	                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* If "SUB STEP	3: CHECK FOR ZERO OBSERVATIONS"	detects no observations it will gracefully exit the process at*/
/* this line.																								  */
/*------------------------------------------------------------------------------------------------------------*/
%exit_now_no_obs:
%put NOTE: PROCESSING HAS CONDITIONALLY STOPPED DUE TO ZERO OBSERVATIONS DETECTED;
%put NOTE: PLEASE CHECK WORK.READLOGS TO RESOLVE THE ISSUE AND THEN RESUBMIT;
/*============================================================================================================*/
/* CLEAN UP								                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* The final step in the macro is to clean up any of the temporary tables created. Warning may be generated	  */
/* if the macro exits early. Check the log, code comments and usage guide to resolve before submitting again  */
/*------------------------------------------------------------------------------------------------------------*/
     proc datasets lib=work nolist;
           delete _connect_spawner_log:;
		   delete _logs_connect;
		   delete readlogs;
     run;

%mend;
/*%connect_spawn_log_read;*/
/*%connect_spawn_log_read(outtbl=connect_server_logs, config_location=C:\SAS\Config\Lev1\ConnectSpawner\Logs\temp);*/
/*%connect_spawn_log_read(config_location=C:\SAS\Config\Lev1\ConnectSpawner\Logs\temp);*/


