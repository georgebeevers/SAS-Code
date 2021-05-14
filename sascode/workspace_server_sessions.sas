/*============================================================================================================*/
/* WORKSPACE SERVER SESSIONS		                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* identify all active and idle sessions connected to a workspace server. You will need to have admin rights  */
/* to read the metaparms file as you need to connect into this server to obtain the workspace connections	  */
/*------------------------------------------------------------------------------------------------------------*/
/*Read the metaparms file*/
/*This will create macro variables of the key connection values*/
%metaparms_read(metaparm_loc=C:\SAS\Config\Lev1\SASMeta\MetadataServer\metaparms.sas);

/*Get the object spawner host name from metadata*/
%meta_get_objspawn_host;

proc datasets lib=work;
	delete workspace_history;
run;

/*Query the workspace server to get all sessions connected (active and idle)*/
/*This will use input from the previous two macros*/

/*Looping criteria has been commented out. Uncomment and amend for looping.*/
/*An SCD table would be better to load the data in as the SERVERID is unique for each session. This would */
/*allow a smaller footprint but include an extra few steps to build the process*/

%macro workspace_session_loop();
/*	%let _time_start=%sysfunc(datetime(),datetime20.);*/
/*	%let end_date=%sysfunc(intnx(day,%sysfunc(today()),1,b));*/
/*	%put &end_date;*/
/*	%put &_time_start.;*/
	/*Create a datetime for each loop*/
	data _null_;
		call symput('tdate',put(datetime(),datetime20.));
	run;

	%put &tdate;

	%meta_get_workspace(table=workspace_sessions);

	/* Convert the idle time value to a number. */
	/*Load the history*/
	%if %sysfunc(exist(workspace_history)) %then
		%do;

			proc sql;
				insert into workspace_history
					select 
						"&tdate" as DTTM
						,* from
						workspace_sessions;
			quit;

		%end;
	%else
		%do;

			proc sql;
				create table workspace_history as
					select 
						"&tdate" as DTTM 
						,* from
						workspace_sessions;
			quit;

		%end;

	/* EXIT WHEN 24HRS HAS PASSED*/
/*	%if %sysfunc(today()) >= &end_date. and %sysfunc(int(%sysfunc(time()))) > %eval(3600*3) %then*/
/*		%goto skip;*/

	/*SLEEP FOR 10MINS - 60SECONDS*/
/*	%let a=%sysfunc(sleep(600,1));*/
/*	%goto start_check;*/

	/*EXIT LOOP*/
/*%skip:*/
%mend;

%workspace_session_loop;