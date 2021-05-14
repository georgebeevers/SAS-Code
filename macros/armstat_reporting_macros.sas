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

%macro time_base();
/*Get cont of applications  - used for the base heat maps*/
proc sql noprint;
	select 
	distinct application as app  
	, count(distinct application) as count
	into: appsused1 - ,:APPCOUNT 
		from m_VA0.sas_application_stats;
/*group by 1;*/
quit;
	%do i=1 %to &APPCOUNT.;

		data _time_tree_1_&i.;
			length application $100.;
			set base_1;
			application="&&appsused&i.";
		run;

		data _time_tree_3_&i.;
			length application $100.;
			set base_3;
			application="&&appsused&i.";
		run;

				data _time_tree_6_&i.;
			length application $100.;
			set base_6;
			application="&&appsused&i.";
		run;
		
				data _time_tree_12_&i.;
			length application $100.;
			set base_12;
			application="&&appsused&i.";
		run;

	%end;

	data heatmap_tree_1;
		set _time_tree_1:;
	run;

	data heatmap_tree_3;
		set _time_tree_3:;
	run;
		data heatmap_tree_6;
		set _time_tree_6:;
	run;
			data heatmap_tree_12;
		set _time_tree_12:;
	run;

	proc datasets lib=work noprint;
		delete _:;
/*		delete base:;*/
	run;

%mend;

/*============================================================================================================*/
/* HORIZONTAL BAR GRAPH									                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create horizontal bar graphs for different data points							 						  */
/* 1. HBAR OPTIONS																							  */
/* HOSTNAME = Show data split by all available servers in the cluster										  */
/* APPLICATION = SAS Data Integration, Base, Enterprise Guide, etc											  */
/* USERID = show by all in scope userids. Restrict before using at enterprise level due to volume			  */
/* DAY = Monday - Sunday																					  */
/* WEEK =  Week Number 1-52																					  */
/* MONTH = January - December																				  */
/* 2. RESPONSE OPTIONS - the data point to display															  */
/* SESSIONTIME -The length of time in minutes the session was open for										  */
/* USERCPU - the amount of time (seconds) the CPU was busy executing code in user space						  */
/* SYSTEMCPU - the amount of time the CPU was busy executing code in kernel space							  */
/* MEMORYUSED - memory consumed for the session																  */
/* IOCOUNT - IO used in the sesssion																		  */
/* 3. STAT OPTIONS																							  */
/* FREQ | MEAN | MEDIAN | PERCENT | SUM																		  */
/* 4. ALLPOP OPTION																							  */
/* Set to N if you want to remove any session which has less than 10 seconds or usercpu and systemcpu. This   */
/* number can be adjusted depending on what is deemed no activity. The default is to report on everything     */
/*------------------------------------------------------------------------------------------------------------*/
%macro armstat_hbar(hbaropt=,response=,stat=,allpop=Y);

	proc sql noprint;
		select count(*) into: totalpop
			from heatmap_bands;
	quit;

	proc sql noprint;
		select count(*) into: inactivepop
			from heatmap_bands
				where systemcpu<10 or usercpu<10;
	quit;
%if &allpop=N %then %do;
	Title "%sysfunc(propcase(&Response.)) Metric since &dt_hist";
	Title2 "Statistic Type = %sysfunc(upcase(&stat.))";
	Title3 "Showing Data By %sysfunc(propcase(&hbaropt))";
	Title4 'Inactive Sessions Removed';

	proc sgplot data=heatmap_bands;
		/*series x=datetime y=SessionTime;*/
		hbar &hbaropt.  /response=&response. stat=&stat. datalabel datalabelfitpolicy=none;
		inset ("Total Number =" = "&totalpop."
			"Inactive Removed = " = "&inactivepop."
			"Active =" = "%eval(&totalpop-&inactivepop)") / backcolor=yellow border;
		where systemcpu>=10 or usercpu>=10;
	run;
%end;
%else %do;
	Title "%sysfunc(propcase(&Response.)) Metric since &dt_hist";
	Title2 "Statistic Type = %sysfunc(upcase(&stat.))";
	Title3 "Showing Data By %sysfunc(propcase(&hbaropt))";

	proc sgplot data=heatmap_bands;
		/*series x=datetime y=SessionTime;*/
		hbar &hbaropt.  /response=&response. stat=&stat. datalabel datalabelfitpolicy=none;
		inset ("Total Number =" = "&totalpop.") / backcolor=yellow border;
	run;
%end;
	title;
%mend;

/*============================================================================================================*/
/* PANEL GRAPH											                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Use the sessiontime and display the same information on a panel by the application 						  */
/* 1. PANELOPT OPTIONS																						  */
/* HOSTNAME = Show data split by all available servers in the cluster										  */
/* APPLICATION = SAS Data Integration, Base, Enterprise Guide, etc											  */
/* USERID = show by all in scope userids. Restrict before using at enterprise level due to volume			  */
/* DAY = Monday - Sunday																					  */
/* WEEK =  Week Number 1-52																					  */
/* 2. RESPONSE OPTIONS - the data point to display															  */
/* SESSIONTIME -The length of time in minutes the session was open for										  */
/* USERCPU - the amount of time (seconds) the CPU was busy executing code in user space						  */
/* SYSTEMCPU - the amount of time the CPU was busy executing code in kernel space							  */
/* MEMORYUSED - memory consumed for the session																  */
/* IOCOUNT - IO used in the sesssion																		  */
/* 3. STAT OPTIONS																							  */
/* FREQ | MEAN | MEDIAN | PERCENT | SUM																		  */
/* 4. ALLPOP OPTION																							  */
/* Set to N if you want to remove any session which has less than 10 seconds or usercpu and systemcpu. This   */
/* number can be adjusted depending on what is deemed no activity. The default is to report on everything     */
/*------------------------------------------------------------------------------------------------------------*/

%macro armstat_panelby(panelopt=,response=,stat=,allpop=Y);

%if &allpop=N %then %do;
	Title "Panel Statistics for SAS Applciations since &dt_hist";
	Title2 "Panel by %sysfunc(propcase(&panelopt.))";
	Title3 "Metric Used = %sysfunc(propcase(&panelopt.)) and Stat = %sysfunc(propcase(&stat.))";
	Title4 'Inactive Sessions Removed';
	proc sgpanel data=heatmap_bands;
		panelby &panelopt.;
		hbar date  /response=&response. stat=&stat. datalabel datalabelfitpolicy=none;
/*		inset "Total" /border;*/
		where systemcpu>=10 or usercpu>=10;
	run;
	%end;
	%else %do;
	Title "Panel Statistics for SAS Applciations since &dt_hist";
	Title2 "Panel by %sysfunc(propcase(&panelopt.))";
	Title3 "Metric Used = %sysfunc(propcase(&panelopt.)) and Stat = %sysfunc(propcase(&stat.))";
	proc sgpanel data=heatmap_bands;
		panelby &panelopt.;
		hbar date  /response=&response. stat=&stat. datalabel datalabelfitpolicy=none;
	run;
	%end;
	title;
proc datasets lib=work nolist;
delete _:;
run;
%mend;

/*============================================================================================================*/
/* PANEL GRAPH - APPLICATION							                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create a number of heatmaps for the application usage. This will create a combined heatpmap for all 		  */
/* applications on one heatmap. If split=Y then a heatmap for each application is created					  */
/* BANDS																									  */
/* 1 = 1HOUR																								  */
/* 3 = 3HOUR																								  */
/* 6 = 6HOUR																								  */
/* 12= 12HOUR																								  */
/* SPLIT = Set to Y if you want to split the graphs out fro each application. Default is a combined graph	  */
/*------------------------------------------------------------------------------------------------------------*/

%macro heatmap_application(band,split=N);

	proc sql;
		create table heatmap as
			select application
				,time_&band. as time
				,count(*) as count label="Number of Sessions"
			from heatmap_bands
				group by 1,2;
	quit;

proc sql;
	create table heatmap_tree_join as 
		select a.time label="Time Band"
			,a.application
			,b.count as count
		from heatmap_tree_&band. as a
			left outer join
				heatmap as b
				on a.time =b.time
				and a.application=b.application;
quit;

	proc sort data=heatmap_tree_join;
		by application;
	run;

%if &split =Y %then
	%do;
	Title "Heat Map of SAS Application Usage in &band Hour Banding";
	Title2 "Split by Application";

	proc sgplot data=heatmap_tree_join;
		heatmapparm x=time y=application colorresponse=count / colormodel = (white yellow orange Red) outline   discretex;
		text x=time  y=application  text=count/ position=left textattrs=(size=10pt );
		yaxis display=(nolabel);
		gradlegend;

		by application;
	run;
	%end;
%else
	%do;
	Title "Heat Map of SAS Application Usage in &band Hour Banding";
		proc sgplot data=heatmap_tree_join;
		heatmapparm x=time y=application colorresponse=count / colormodel = (white yellow orange Red) outline   discretex;
		text x=time  y=application  text=count/ position=left textattrs=(size=10pt );
		yaxis display=(nolabel);
		gradlegend;

	run;
	%end;
	title;
	proc datasets lib=work noprint;
	delete heatmap;
	delete heatmap_tree_join;
	run;
%mend;

/*============================================================================================================*/
/* HEAT MAP - HOSTNAME									                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Creates a number of heatmaps showing busy periods in time bands for hosts								  */
/*   																										  */
/* BANDS																									  */
/* 1 = 1HOUR																								  */
/* 3 = 3HOUR																								  */
/* 6 = 6HOUR																								  */
/* 12= 12HOUR																								  */
/*------------------------------------------------------------------------------------------------------------*/
%macro heatmap_time_band_host(band);
proc sql;
	create table heatmap as
		select hostname
			,time_&band. as time
			,count(*) as count label="Number of Sessions"
		from heatmap_bands
			group by 1,2;
quit;

proc sql;
	create table heatmap_tree_join as 
		select a.time label="Time Band"
			,b.hostname
			,coalesce(b.count,0) as count
		from heatmap_tree_&band. as a
			left outer join
				heatmap as b
				on a.time =b.time;
quit;

/*proc freq data=busy_band;*/
/*table activityband;*/
/*run;*/
proc sort data=heatmap_tree_join;
	by hostname;
run;

Title "Heat Map of SAS Application Usage in &band Hour Banding";
Title2 'Group by Hostname';

proc sgplot data=heatmap_tree_join;
	heatmapparm x=time y=hostname  colorresponse=count  / colormodel = (white yellow orange Red) outline  discretex;
	text x=time  y=hostname  text=count/ /*position=left*/
	textattrs=(size=10pt );
	yaxis display=(nolabel);
	gradlegend / EXTRACTSCALE;
run;
title;

proc datasets lib=work noprint;
	delete heatmap;
	delete heatmap_tree_join;
run;
%mend;

/*============================================================================================================*/
/* HEAT MAP - MULTIPLE VALUES							                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Creates a number of heatmaps showing busy periods for calendar parameters such as day, week and month. This*/
/* allows a higher level view of the systems hotspots to be viewed											  */
/* BANDS																									  */
/* XVALUE - day, week, month																				  */
/* YVALUE - hostname, applicatoin, userid																	  */
/* SPLIT  - Create seperate graphs with =Y or default of combined											  */
/*------------------------------------------------------------------------------------------------------------*/
%macro heatmap_calendar(xvalue,yvalue=hostname,split=N);
proc sql;
	create table heatmap as
		select &yvalue.
			,&xvalue.
			,count(*) as count label="Number of Sessions"
		from heatmap_bands
			group by 1,2;
quit;

proc sort data=heatmap;
	by &yvalue.;
run;

%if &split =Y %then
	%do;
		Title 'Peak Days of Usage by Hostname';
		Title2 "Split appliced by &YVALUE.";

		proc sgplot data=heatmap;
			heatmapparm x=&xvalue. y=&yvalue.  colorresponse=count  / colormodel = (white yellow orange Red) outline  discretex;
			text x=&xvalue.  y=&yvalue.  text=count/ /*position=left*/
			textattrs=(size=10pt );
			yaxis display=(nolabel);
			gradlegend / EXTRACTSCALE;
			by &yvalue.;
		run;

	%end;
%else
	%do;
		Title 'Peak Days of Usage by Hostname';

		proc sgplot data=heatmap;
			heatmapparm x=&xvalue. y=&yvalue.  colorresponse=count  / colormodel = (white yellow orange Red) outline  discretex;
			text x=&xvalue.  y=&yvalue.  text=count/ /*position=left*/
			textattrs=(size=10pt );
			yaxis display=(nolabel);
			gradlegend / EXTRACTSCALE;
		run;

	%end;

title;

proc datasets lib=work noprint;
	delete heatmap;
	delete heatmap_tree_join;
run;
%mend;