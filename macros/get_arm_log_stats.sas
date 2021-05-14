/**********************************************************************************************************************
 * Name:          getfilelist.sas
 *
 * Type:          SAS Macro
 *
 * Description:   Generates a Table with one row for each file or directory found. 
 *                Also has the ability to find files and directories in sub-directories.
 *                
 * Parameters:    Path        Path of the directory to start the search from
 *                Table       Name of the SAS Table to be created/appended with the list of files and directories
 *                            Important! The rows generated by this macro will be appended to the table, if the table
 *                                       already exist you may get unexpected results.
 *                TypeFilter  If specified the generated SAS Table will only contain the specified file types.
 *                Recursive   Should be set to either YES or NO.
 *                            YES means that files and directories from sub-directories will be included.
 *                            NO means that only the specified Path will be examined.
 *                DirNumber   This parameter should NOT be used. The parameter is used when doing a recursive search.
 *                
 * Created:       24.Feb.2012, Michael Larsen, SAS Institute
 *                
 * Example:
 *
 * Generate a list of Files and Directories found in C:\Temp including Files and Directories found in sub-Directories.
 * %GetFileList(Path=C:\Temp, Table=Files, Recursive=Yes);
 *
 * Generate a list of Files of the filetypes PDF or XLSX found in C:\Temp.
 * %GetFileList(Path=C:\Temp, Table=Files, TypeFilter=PDF XLSX, Recursive=Yes);
 *                
 **********************************************************************************************************************/
/*%include 'C:\temp\GIT\SAS-Code\macros\get_obscnt.sas';*/
/*%include 'C:\temp\GIT\SAS-Code\macros\clean_up.sas';*/
/*%include 'C:\temp\GIT\SAS-Code\macros\getfilelist.sas';*/
%macro get_arm_log_stats(series=1,outtbl=,history=,config_location=);
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
		%let outtbl=arm_sessions;
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
	Table=work.arm_logs,
	Typefilter=log
	);
	%end;
%if %length(&config_location)=0 %then %do;
%getfilelist(
	Path=%sysfunc(getoption(SASINITIALFOLDER))&os_set_delim.WorkspaceServer&os_set_delim.PerfLogs,
	Table=work.arm_logs,
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

		proc sql;
			select min(datepart(created)) format=date9. into: dt_hist
				from arm_logs;
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
	set arm_logs;
	where membername like 'arm4%'
		and Filesize > 0 and datepart(created)>="&dt_hist."d and entrytype ="File";
run;

/*------------------------------------------------------------------------------------------------------------*/
/* SUB STEP	3: CHECK FOR ZERO OBSERVATIONS																	  */
/*------------------------------------------------------------------------------------------------------------*/
/* If work.readlogs contains no observations the process will exit the macro early and place a NOTE: into the */
/* log asking for the input data to be checked. 															  */
/*------------------------------------------------------------------------------------------------------------*/

%if %get_obscnt(readlogs)=0 %then
	%do;
		%put NOTE: NO OBSERVATIONS FOUND;
		%goto exit_now_no_obs;
	%end;
%else
	%do;
		%put NOTE: OBSERVATIONS = %get_obscnt(readlogs);
	%end;
/*------------------------------------------------------------------------------------------------------------*/
/* PROCESS THE ARM LOG																						  */
/*------------------------------------------------------------------------------------------------------------*/
/* If observations are found in readlogs then the logs will be processed. A number of steps takes place to get*/
/* the data read in correctly																				  */
/*------------------------------------------------------------------------------------------------------------*/
data 
  InitRecord  (keep=dttm Appname ParentProcess ChildProcess
                    SessionDTTM ProcessId ApplicationName Userid Hostname Timestamp ApplicationID UserTimestamp SystemTimestamp ApplicationName Userid)
  IDRecord    (keep=SessionDTTM ProcessId ApplicationName Userid Hostname Timestamp ApplicationID TransactionClassId TransactionName TransactionType 
                    dttm Appname ParentProcess ChildProcess TransactionFields)
  StartRecord (keep=SessionDTTM ProcessId ApplicationName Userid Timestamp ApplicationName ApplicationID TransactionClassId TransactionId UserTimestamp 
                    dttm Appname ParentProcess ChildProcess SystemTimestamp Libref Datatype Nobs Nvars NobsRead Member Step IOCount MemoryUsed Hostname)
  StopRecord  (keep=SessionDTTM ProcessId ApplicationName Userid Hostname Timestamp ApplicationName ApplicationID TransactionClassId TransactionId 
                    dttm Appname ParentProcess ChildProcess UserTimestamp TransactionClassId SystemTimestamp Libref Datatype Nobs Nvars NobsRead Member Step IOCount MemoryUsed Hostname)
  UpdateRecord(keep=SessionDTTM ProcessId ApplicationName Userid Hostname Timestamp ApplicationName ApplicationID TransactionClassId TransactionId 
                    dttm Appname ParentProcess ChildProcess UserTimestamp SystemTimestamp Updatetype Updatevalue)
  EndRecord   (keep=SessionDTTM ProcessId ApplicationName Userid Hostname Timestamp ApplicationName ApplicationID UserTimestamp SystemTimestamp
                    dttm Appname ParentProcess ChildProcess)
  ;
  length DTTM 8 Appname $50 ParentProcess ChildProcess $56
         Updatetype $8 Updatetype1 Updatetype2 $500 Updatevalue $1000 TransactionFields $500
         SessionDTTM ProcessId 8 ApplicationName Userid Hostname Libref Datatype Member Step $100;
  call missing(Updatetype1,Updatetype2,Updatetype,Updatevalue);
  drop Updatetype1 Updatetype2;
  retain SessionDTTM ProcessId 0 Userid '';
  retain Hostname ApplicationName Libref Datatype Member Step '';

  set readlogs;
  logfile = fullname;
  SessionDTTM = dhms(input(scan(membername,-4,'_'),yymmdd10.),
                     input(substr(scan(membername,-3,'_'),1,2),2.),
                     input(substr(scan(membername,-3,'_'),4,2),2.),
                     input(substr(scan(membername,-3,'_'),7,2),2.));
  ProcessID = input(scan(membername,-2,'_.'),8.);
  Hostname = scan(membername,-3,'_.');

  infile perflogs filevar=logfile end=eof length=len column=col
         recfm=v dlm=',' truncover share ;
  putlog 'NOTE: Reading "' membername +(-1) '"...';
  recno=0;
  startdttm = datetime();
  do until (eof);
    recno + 1;
    input
     @'|' @'|' @'|' @'|' 
     @;
    *if mod(recno,50000) = 0 then putlog 'NOTE: Reading record number ' recno commax20. +1 col= len=;
    /* Sometimes, the previous input statement causes that column to be greater than than 
     * the record and never skips to the next record, causing it to loop. Therefore we check to see 
     * if the column pointer is greater than the record length.                                     */
    if col >= len then do; 
      input;
      continue;
    end;
    dttm = input(scan(_infile_,1,'|'),e8601dt23.3);
    Appname = scan(_infile_,2,'|');
    ParentProcess = scan(_infile_,3,'|');
    ChildProcess = scan(_infile_,4,'|');

    input
      RecordType      :$1.
      Timestamp       :20.
      ApplicationID   :10.
      @
    ;
    select (RecordType);
      when ('I') /* Initialization */
        do;
          input 
            UserTimestamp   :20.
            SystemTimestamp :20.
            ApplicationName :$100.
            Userid          :$100.
            ;
          output InitRecord;
        end;
      when ('G') /* GetID */
        do;
          input 
            TransactionClassId      :$1.
            TransactionName         :$100.
            TransactionType         :$100.
            ;
          TransactionFields = substr(_infile_, index(_infile_,trim(TransactionType))+length(TransactionType)+1);
          output IDRecord;
        end;
      when ('S') /* Start */
        do;
          input 
            TransactionClassId      :$1.
            @
            ;
          if TransactionClassId = '1' then 
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              ApplicationName :$100.
              IOCount         :32.
              MemoryUsed      :32.
            ;
          else if TransactionClassId = '2' then
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              Libref          :$32.
              Datatype        :$32.
              Nobs            :32.
              Nvars           :32.
              NobsRead        :32.
              Member          :$32.
            ;
          else if TransactionClassId = '3' then
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              Step            :$32.
              IOCount         :32.
              MemoryUsed      :32.
              ;
          output StartRecord;
        end;
      when ('P') /* Stop  */
        do;
          input 
            TransactionClassId      :$1.
            @
            ;
          if TransactionClassId = '1' then 
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              dummy           :$100.
              ApplicationName :$100.
              IOCount         :32.
              MemoryUsed      :32.
          ;
          else if TransactionClassId = '2' then
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              dummy           :$100.
              Libref          :$32.
              Datatype        :$32.
              Nobs            :32.
              Nvars           :32.
              NobsRead        :32.
              Member          :$32.
            ;
          else if TransactionClassId = '3' then
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              dummy           :$100.
              Step            :$32.
              IOCount         :32.
              MemoryUsed      :32.
              ;
          if findc(Step,'(') then Step = substr(Step,1,indexc(Step,'(')-1);
          output StopRecord;
        end;
      when ('U') /* Update */
        do;
          input 
            TransactionClassId      :$1.
            @
            ;
          if TransactionClassId = '1' then 
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              dummy           :$100.
              Updatetype1     :$500.
              Updatetype2     :$500.
          ;
          else if TransactionClassId = '2' then
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              dummy           :$100.
              Updatetype1     :$500.
              Updatetype2     :$500.
            ;
          else if TransactionClassId = '3' then
            input
              TransactionId   :20.
              UserTimestamp   :20.
              SystemTimestamp :20.
              dummy           :$100.
              Updatetype1     :$500.
              Updatetype2     :$500.
              ;
          if Updatetype1 = 'WHERE(0)' then do;
            Updatetype = 'WHERE';
            Updatevalue = substr(_infile_,index(_infile_,'WHERE')+9);
          end;
          else if index(Updatetype1,'VAR(') > 0 then do;
            Updatetype = 'VAR';
            Updatevalue = substr(_infile_,index(_infile_,'VAR(')+6);
            Updatevalue = substr(Updatevalue,1, find(Updatevalue,')',-999)-1);
          end;
          else do;
            Updatetype = 'UNKNOWN';
            Updatevalue = catx(',',Updatetype1,Updatetype2);
          end;
          output UpdateRecord;
        end;
      when ('E') /* End */
        do;
          input 
              UserTimestamp   :20.
              SystemTimestamp :20.
          ;
          output EndRecord;
        end;
      otherwise
        if RecordType ne '' then putlog 'WARNING: Unknown Recordtype: ' RecordType;
    end;
  end;
  duration = put(timepart(datetime() - startdttm),time12.3);
  putlog 'NOTE: Done reading "' membername +(-1) '".';
  putlog 'NOTE: Records read: ' recno  ',Elapsed time: ' duration;
  format SessionDTTM Timestamp datetime22.3 UserTimestamp SystemTimestamp time18.6 recno commax16. dttm e8601dt23.3;
  drop recno startdttm duration;
run;

/*******************************************************************************************
 * Reset the log back to the log window, if previously redirected.
 *******************************************************************************************/
/*proc printto log=log;run;*/

/*******************************************************************************************
 * Combine the start, update and end records
 *******************************************************************************************/
proc sql noprint;
  create table arm_steps as
    select distinct
      a.SessionDTTM,
      a.ProcessId,
      a.ApplicationName,
      a.Userid,
      a.Hostname,
      a.TransactionClassId,
      a.TransactionId,
      a.Libref,
      a.Datatype,
      a.Member,
      a.Step,
      a.Nobs,
      a.Nvars,
      b.Updatetype,
      b.Updatevalue,
      a.IOCount as StartIOCount,
      a.MemoryUsed as StartMemoryUsed,
      c.IOCount as StopIOCount,
      c.MemoryUsed as StopMemoryUsed,
      c.NobsRead,
      a.Timestamp format=datetime22.3 as StartTimestamp,
      c.Timestamp format=datetime22.3 as EndTimestamp,
      c.Timestamp - a.Timestamp format=time10.3 as RealTimeUsed

    from StartRecord a
    left join
         UpdateRecord b
    on    a.SessionDTTM = b.SessionDTTM
      and a.ProcessId   = b.ProcessId
      and a.Userid      = b.Userid
      and a.TransactionClassId = b.TransactionClassId
      and a.TransactionId = b.TransactionId
    left join
         StopRecord c
    on    a.SessionDTTM = c.SessionDTTM
      and a.ProcessId   = c.ProcessId
      and a.Userid      = c.Userid
      and a.TransactionClassId = c.TransactionClassId
      and a.TransactionId = c.TransactionId
    where a.Datatype is not null 
/*      and a.Libref not in ('WORK','SASHELP')*/
/*      and a.processid = 20392*/
    order by 
      a.SessionDTTM,
      a.ProcessId,
      a.Timestamp,
      a.ApplicationName,
      a.Userid,
      a.Hostname,
      a.TransactionId,
      a.TransactionClassId
  ;
quit;

/*******************************************************************************************
 * Create VARS and WHERE variables 
 * Keep only the last record for each unique transactionId
 *******************************************************************************************/
data Arm_Steps;
  set Arm_Steps;
  by SessionDTTM ProcessId StartTimestamp ApplicationName Userid Hostname TransactionId;
  length Vars $32767 Where $32767;
  retain Vars '' Where '';
  if first.TransactionId then do;
    Vars = '';
    Where = '';
  end;
  if UpdateType = 'VAR' then Vars = catx(' ',Vars,UpdateValue);
  else if UpdateType = 'WHERE' then Where = catx(' ',Where,UpdateValue);
  if last.TransactionId;
  drop UpdateType UpdateValue;
run;

/*******************************************************************************************
 * Combine Init and End Stop records
 *******************************************************************************************/
proc sql noprint;
  create table &outtbl._&series. as
    select distinct
      a.SessionDTTM,
      a.ProcessId,
      a.ApplicationName,
      a.Userid,
      a.Hostname,

	  round(max(b.UserTimestamp)-min(a.UserTimestamp)) as UserCPU_SECS,
	  round(max(b.SystemTimestamp)-min(a.SystemTimestamp)) as SystemCPU_SECS,
	  round((max(b.Timestamp)-min(a.Timestamp))/60) as SessionTime_MINS,
      min(a.Timestamp) format=datetime22.3 as InitTimestamp,
      max(b.Timestamp) format=datetime22.3 as EndTimestamp,
      max(b.Timestamp) - min(a.Timestamp) format=time10.3 as RealTimeUsedSession,
	  c.memoryused,
	  c.iocount
    from Initrecord a
    left join 
         EndRecord b
    on    a.SessionDTTM = b.SessionDTTM
      and a.ProcessId   = b.ProcessId
      and a.Userid      = b.Userid
	  left join
	stoprecord as c
	on a.processid = c.processid
    group by 
      a.SessionDTTM,
      a.ProcessId,
      a.ApplicationName,
      a.Userid,
      a.Hostname
    having calculated RealTimeUsedSession is not null
    order by 
      a.SessionDTTM,
      a.ProcessId,
      a.Userid
  ;
quit;

%clean_up(readlogs);
%clean_up(initrecord);
%clean_up(idrecord);
%clean_up(startrecord);
%clean_up(stoprecord);
%clean_up(updaterecord);
%clean_up(endrecord);
%clean_up(arm_steps);
%clean_up(arm_logs);

%exit_now_no_obs:
%put NOTE: PROCESSING HAS CONDITIONALLY STOPPED DUE TO ZERO OBSERVATIONS DETECTED;
%put NOTE: PLEASE CHECK WORK.READLOGS TO RESOLVE THE ISSUE AND THEN RESUBMIT;
%mend;
/*%get_arm_log_stats(config_location=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\PerfLogs\temp);*/
/*%get_arm_log_stats(config_location=C:\SAS\Config\Lev1\SASApp\ConnectServer\george\temp);*/
/*%get_arm_log_stats(history=10);*/
/*%get_arm_log_stats(outtbl=george,history=10);*/

