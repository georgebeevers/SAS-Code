%macro sas_application_reporting(intbl=,history=,user=);
%if %length(&intbl)>0 %then
	%do;
	data sas_applications_used;
	set &intbl;
	run;
	%end;
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
%put NOTE: ALL FILES WILL BE READ IN %sysfunc(getoption(SASINITIALFOLDER))&os_set_delim.ObjectSpawner&os_set_delim.Logs ;

%end;

/*------------------------------------------------------------------------------------------------------------*/
/* REPORTING DATE DEFAULT																					  */
/*------------------------------------------------------------------------------------------------------------*/
/* Set the reporting default date to the start of the previous month. If more is required then the number of  */
/* days can be provided																						  */
/*------------------------------------------------------------------------------------------------------------*/
%if %eval(&history+0) = 0 %then
	%do;

	data _null_;
		call symput("dt_hist",PUT(intnx('Month',today(),-1),date9.));
	run;

		%put &dt_hist.;
	%end;
/*------------------------------------------------------------------------------------------------------------*/
/* GENERATE MACRO VARIABLES			 																		  */
/*------------------------------------------------------------------------------------------------------------*/
/* Generate macro variables based on sas_applications_used													  */
/*   												*/
/*------------------------------------------------------------------------------------------------------------*/
proc sql noprint; 
select min(date) as date format date9.
,max(date) as date format date9.
,count(*) as count 
into:min_date, :max_date, :app_count 
from sas_applications_used;
quit;
%put &min_date;
%put &app_count;

%if %length(&user)=0 %then
	%do;
		%let userwhere= ;
		%let title_note=;
	%end;
%if %length(&user)>0 %then
	%do;
	%let userwhere=and userid="&user.";
	%let title_note=for &user.; 
%end;

/*------------------------------------------------------------------------------------------------------------*/
/* TABLE 1 - TOP APPLICATION LAUNCHERS SINCE X DATE															  */
/*------------------------------------------------------------------------------------------------------------*/
/* Table showing the users who have launched more than 5 applications in a day since a particular date	      */
/* 	  																										  */
/*------------------------------------------------------------------------------------------------------------*/
Title height=14pt "Users who have launched more than 5 matching applications in a day since &dt_hist";

proc sql;
	select application
		,date
		,userid
		,count(application) as applications_launched label="Applications Launched"
	from sas_applications_used
		where date>="&dt_hist."d
			group by 1,2,3
				having count(application)>=5;
quit;

/*------------------------------------------------------------------------------------------------------------*/
/* TABLE 2 - TOP APPLICATION LAUNCHERS TODAY																  */
/*------------------------------------------------------------------------------------------------------------*/
/* Table showing the users who have launched more than 5 applications today						 		      */
/* 	  																										  */
/*------------------------------------------------------------------------------------------------------------*/
Title height=14pt "Users who have launched more than 5 matching applications today";

proc sql;
	select application
		,date
		,userid
		,count(application) as applications_launched label="Applications Launched"
	from sas_applications_used
		where date>="&max_date"d
			group by 1,2,3
				having count(application)>=5;
quit;
Title;
footnote;

/*------------------------------------------------------------------------------------------------------------*/
/* CHART 1 - APPLICATION USAGE OVER TIME																	  */
/*------------------------------------------------------------------------------------------------------------*/
/* Chart the usage of SAS applications over a period of time. The data will be displayed as a stacked bar     */
/* graph.																									  */
/*------------------------------------------------------------------------------------------------------------*/
PROC SGPLOT DATA = sas_applications_used;
VBAR date/group=application;
where date>="&dt_hist."d &userwhere.;
Title height=14pt "SAS Applications Used since &dt_hist &title_note.";
footnote height=8pt  "Data represents ALL applications which have connected to the server in the specified period";
footnote2 height=8pt "A successful connection to the server means a job slot has been allocated";
RUN;
Title;
footnote;
/*------------------------------------------------------------------------------------------------------------*/
/* CHART 2 - APPLICATION USAGE PIE CHART																	  */
/*------------------------------------------------------------------------------------------------------------*/
/* Chart the usage of SAS applications over a period of time. The data will be displayed as a pie chart	      */
/*------------------------------------------------------------------------------------------------------------*/
/*PIE CHART START*/
PROC TEMPLATE;
   DEFINE STATGRAPH pie;
      BEGINGRAPH;
         LAYOUT REGION;
            PIECHART CATEGORY = application /
            DATALABELLOCATION = OUTSIDE
			DATALABELCONTENT = ALL
            CATEGORYDIRECTION = CLOCKWISE
			DATASKIN = SHEEN
            START = 180 NAME = 'pie';
            DISCRETELEGEND 'pie' /
            TITLE = 'SAS Applications';
         ENDLAYOUT;
      ENDGRAPH;
   END;
RUN;
PROC SGRENDER DATA = sas_applications_used (where=(date>="&dt_hist."d &userwhere.))
            TEMPLATE = pie;
		Title height=14pt "Aggregated SAS Applications used since &dt_hist &title_note.";
RUN;
/*PIE CHART END*/
Title;

%mend;

