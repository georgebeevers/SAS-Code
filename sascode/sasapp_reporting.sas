/*============================================================================================================*/
/* APPLICATION REPORTING EXAMPLES	                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* THIS PIECE OF CODE PROVIDES REPORTING EXAMPLES ON APPLICATION USAGE. TO RUN THIS YOU NEED TO HAVE SETUP THE*/
/* OBJECT SPANWER AND CONNECT SPAWNER REPORTING WITH ARM STATS ENAABLED IN THE WORKSPACE LOGGERS. IF THIS IS  */
/* NOT PRESENT THEN THIS PIECE OF CODE WILL NOT WORK.														  */
/*																											  */
/* TABLE CREATION CODE = SASAPPS_USAGE_METRICS.SAS (CREATES THE INPUT TABLE)								  */
/*																											  */
/* INPUT DATA																								  */
/* M_VA0.SAS_APPLICATION_STATS																				  */
/*																											  */
/* MACROS - SEE MACRO NOTES AND COMMENTS FOR USAGE															  */
/* %SAS_APPLICATION_REPORTING							 													  */
/* %TIME_BASE										   														  */
/* %ARMSTAT_HBAR																							  */
/* %ARMSTAT_PANELBY																							  */
/* %HEATMAP_APPLICATION																					      */
/* %HEATMAP_TIME_BAND_HOST																					  */
/* %HEATMAP_CALENDAR				 																		  */
/*------------------------------------------------------------------------------------------------------------*/

/*Include the required macros*/
%include 'C:\temp\GIT\SAS-Code\macros\armstat_reporting_macros.sas';
/*============================================================================================================*/
/* ASSIGN LIBNAMES & CREATE DATE	                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Libname to M_VA0 is assigned and the date macro set to the last 90 days. If more history is required then  */
/* change the parameter. Some macros have the option to set locally for that graph. This will restrict the 	  */
/* data before the local macro can adjust it.																  */
/*------------------------------------------------------------------------------------------------------------*/
libname m_va0 'C:\temp\SAS_Data\server_metrics\m_va0';
data _null_;
	call symput("dt_hist",PUT(intnx('day',today(),-90),date9.));
run;

/*Busy Bands*/
/*Show when the greatest number of sessions are active*/
proc format;
	value day_names
		1='Sunday'
		2='Monday'
		3='Tuesday'
		4='Wednesday'
		5='Thursday'
		6='Friday'
		7='Saturday';
	value month_names
		1='January'
		2='February'
		3='March'
		4='April'
		5='May'
		6='June'
		7='July'
		8='August'
		9='September'
		10='October'
		11='November'
		12='December';
run;


data base_1 (drop=time_tree_base);
	format time_tree_base $10. time time10.;
	infile datalines dsd missover;
	input time_tree_base time;
	time=input(time_tree_base,time10.);
	datalines;
00:00:00
01:00:00
02:00:00
03:00:00
04:00:00
05:00:00
06:00:00
07:00:00
08:00:00
09:00:00
10:00:00
11:00:00
12:00:00
13:00:00
14:00:00
15:00:00
17:00:00
18:00:00
19:00:00
20:00:00
21:00:00
22:00:00
23:00:00
;
run;

data base_3 (drop=time_tree_base);
	format time_tree_base $10. time time10.;
	infile datalines dsd missover;
	input time_tree_base time;
	time=input(time_tree_base,time10.);
	datalines;
03:00:00
06:00:00
09:00:00
12:00:00
15:00:00
18:00:00
21:00:00
00:00:00
;
run;
data base_6 (drop=time_tree_base);
	format time_tree_base $10. time time10.;
	infile datalines dsd missover;
	input time_tree_base time;
	time=input(time_tree_base,time10.);
	datalines;
06:00:00
12:00:00
18:00:00
24:00:00
;
run;
data base_12 (drop=time_tree_base);
	format time_tree_base $10. time time10.;
	infile datalines dsd missover;
	input time_tree_base time;
	time=input(time_tree_base,time10.);
	datalines;
12:00:00
24:00:00
;
run;

/*Create time band tables*/
%time_base;

/*============================================================================================================*/
/* AVERAGE SESSION TIME    			                                    								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create a graph showing the average session time. A second graph exists which filters out sessions with only*/
/* 10 seconds or less system or user cpu time. This may need to be adjusted once a larger population is 	  */
/* examined. Other markers can be used to determine inactive sessions										  */
/*------------------------------------------------------------------------------------------------------------*/
proc sql;
	create table heatmap_bands as
		select 
/*			application*/
/*			,hostname*/
		*
			,intnx('hour',time,0,'B') as time_1 format=time10.
			,
		case 
			when intnx('hour',time,0,'B') in ('01:00:00't,'02:00:00't,'03:00:00't) then '03:00:00't
			when intnx('hour',time,0,'B') in ('04:00:00't,'05:00:00't,'06:00:00't) then '06:00:00't
			when intnx('hour',time,0,'B') in ('07:00:00't,'08:00:00't,'09:00:00't) then '09:00:00't
			when intnx('hour',time,0,'B') in ('10:00:00't,'11:00:00't,'12:00:00't) then '12:00:00't
			when intnx('hour',time,0,'B') in ('13:00:00't,'14:00:00't,'15:00:00't) then '15:00:00't
			when intnx('hour',time,0,'B') in ('16:00:00't,'17:00:00't,'18:00:00't) then '18:00:00't
			when intnx('hour',time,0,'B') in ('19:00:00't,'20:00:00't,'21:00:00't) then '21:00:00't
			when intnx('hour',time,0,'B') in ('22:00:00't,'23:00:00't,'00:00:00't) then '00:00:00't
		end 
	as time_3 format=time10.
				,
		case
			when intnx('hour',time,0,'B') in ('01:00:00't,'02:00:00't,'03:00:00't,'04:00:00't,'05:00:00't,'06:00:00't) 
			then '06:00:00't
			when intnx('hour',time,0,'B') in ('07:00:00't,'08:00:00't,'09:00:00't,'10:00:00't,'11:00:00't,'12:00:00't) 
			then '12:00:00't
			when intnx('hour',time,0,'B') in ('13:00:00't,'14:00:00't,'15:00:00't,'16:00:00't,'17:00:00't,'18:00:00't) 
			then '18:00:00't
			when intnx('hour',time,0,'B') in ('19:00:00't,'20:00:00't,'21:00:00't,'22:00:00't,'23:00:00't,'00:00:00't) 
			then '24:00:00't
		end 
	as time_6 format=time10.
					,
		case
			when intnx('hour',time,0,'B') in ('01:00:00't,'02:00:00't,'03:00:00't,'04:00:00't,'05:00:00't,'06:00:00't
,'07:00:00't,'08:00:00't,'09:00:00't,'10:00:00't,'11:00:00't,'12:00:00't) 
			then '12:00:00't
			when intnx('hour',time,0,'B') in ('13:00:00't,'14:00:00't,'15:00:00't,'16:00:00't,'17:00:00't,'18:00:00't
,'19:00:00't,'20:00:00't,'21:00:00't,'22:00:00't,'23:00:00't,'00:00:00't) 
			then '24:00:00't
		end 
	as time_12 format=time10.
		,weekday(date) as day format=day_names.
		,week(date) as week
/*		,systemcpu*/
/*		,usercpu*/
		,month(date) as month format=month_names.
		/*,year(date) as year*/

	/*,count(application) as count*/
	from m_VA0.sas_application_stats;

	/*group by 1,2,3,4,5,6;*/
quit;
/*============================================================================================================*/
/* SUMMARY GRAPHS										                  								  	  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Create summary graphs from the main table and display the data for the last two months by default		  */
/* OPTIONS																									  */
/* INTBL - Table to use for reporting. This will be from the object spawner, connect spawner and ARM Stats	  */
/* HISTORY = Set this to adjust from the default postion													  */
/* USER = Include a username to subset the data	and display their usage only								  */
/*------------------------------------------------------------------------------------------------------------*/
%sas_application_reporting(intbl=heatmap_bands);
/*Show usage for the last 20 days*/
%sas_application_reporting(intbl=heatmap_bands, history=20);
/*Last 20 days and one user*/
%sas_application_reporting(intbl=heatmap_bands, history=20,user=sukgeb_local@sukgeb);

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
/*============================================================================================================*/
/* EXAMPLE USAGE					                                    								  	  */
/*============================================================================================================*/

/*Macro Usage - Show ALL grapsh which can be created*/
/*SESSIONTIME*/
%armstat_hbar(hbaropt=day,response=sessiontime,stat=mean);
%armstat_hbar(hbaropt=week,response=sessiontime,stat=mean);
%armstat_hbar(hbaropt=month,response=sessiontime,stat=mean);
/*USERCPU*/
%armstat_hbar(hbaropt=day,response=usercpu,stat=mean);
%armstat_hbar(hbaropt=week,response=usercpu,stat=mean);
%armstat_hbar(hbaropt=month,response=usercpu,stat=mean);
/*SYSTEMCPU*/
%armstat_hbar(hbaropt=day,response=systemcpu,stat=mean);
%armstat_hbar(hbaropt=week,response=systemcpu,stat=mean);
%armstat_hbar(hbaropt=month,response=systemcpu,stat=mean);
/*IOCOUNT*/
%armstat_hbar(hbaropt=day,response=iocount,stat=mean);
%armstat_hbar(hbaropt=week,response=iocount,stat=mean);
%armstat_hbar(hbaropt=month,response=iocount,stat=mean);
/*MEMORYUSED*/
%armstat_hbar(hbaropt=day,response=memoryused,stat=mean);
%armstat_hbar(hbaropt=week,response=memoryused,stat=mean);
%armstat_hbar(hbaropt=month,response=memoryused,stat=mean);
/*Show Sessiontime by the applications and then remove those with low SYSTEM and USERCPU*/
%armstat_hbar(hbaropt=application,response=sessiontime,stat=mean);
%armstat_hbar(hbaropt=application,response=sessiontime,stat=mean,allpop=N);
/*Show Sessiontime by the applications and then remove those with low SYSTEM and USERCPU*/
%armstat_hbar(hbaropt=hostname,response=sessiontime,stat=mean);
%armstat_hbar(hbaropt=hostname,response=sessiontime,stat=mean,allpop=N);
/*Show sessiontime by the userid and then remove those with low SYSTEM and USERCPU*/
/*In large systems add a where clause to restrict userids as SAS HBAR Graphs will struggle with */
/*the volume of users. Switch to VA */
%armstat_hbar(hbaropt=userid,response=sessiontime,stat=mean);
%armstat_hbar(hbaropt=userid,response=sessiontime,stat=mean,allpop=N);


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
/*============================================================================================================*/
/* EXAMPLE USAGE					                                    								  	  */
/*============================================================================================================*/
/*Show panel output for application and hte main stats*/
%armstat_panelby(panelopt=application,response=sessiontime,stat=mean);
%armstat_panelby(panelopt=application,response=usercpu,stat=mean);
%armstat_panelby(panelopt=application,response=systemcpu,stat=mean);
%armstat_panelby(panelopt=application,response=memoryused,stat=mean);
%armstat_panelby(panelopt=application,response=IOCOUNT,stat=mean);
/*Repeat and remove inactive sessions*/
%armstat_panelby(panelopt=application,response=sessiontime,stat=mean,allpop=N);
%armstat_panelby(panelopt=application,response=usercpu,stat=mean,allpop=N);
%armstat_panelby(panelopt=application,response=systemcpu,stat=mean,allpop=N);
%armstat_panelby(panelopt=application,response=memoryused,stat=mean,allpop=N);
%armstat_panelby(panelopt=application,response=IOCOUNT,stat=mean,allpop=N);
/*Show hostname, userid,data and week example*/
%armstat_panelby(panelopt=hostname,response=sessiontime,stat=mean);
%armstat_panelby(panelopt=userid,response=sessiontime,stat=mean);
%armstat_panelby(panelopt=day,response=sessiontime,stat=mean);
%armstat_panelby(panelopt=week,response=sessiontime,stat=mean);



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

/*Standard Heatmaps*/
%heatmap_application(1);
%heatmap_application(3);
%heatmap_application(6);
%heatmap_application(12);
/*Split Heatmaps*/
/*Standard Heatmaps*/
%heatmap_application(1,split=Y);
%heatmap_application(3,split=Y);
%heatmap_application(6,split=Y);
%heatmap_application(12,split=Y);

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
%heatmap_time_band_host(1);
%heatmap_time_band_host(3);
%heatmap_time_band_host(6);
%heatmap_time_band_host(12);
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
%heatmap_calendar(day,yvalue=application,split=Y);
%heatmap_calendar(day,yvalue=hostname,split=Y);
%heatmap_calendar(day,yvalue=userid,split=Y);
%heatmap_calendar(week);
%heatmap_calendar(month,split=Y);
