/*ARM_STEPS and ARM_SESSIONS will be need for further analysis. ARM logging needs to be enabled*/
/*This will bring in application names, PID, run time and key stats such as IO and memory*/
/* Delete tables from previous run if any */
%macro arm_log_read(history=);

	data _null_;
		call symput("dt_hist",PUT(intnx('day',today(),-&history.),date9.));
	run;
%put %sysfunc(getoption(SASINITIALFOLDER));
%getfilelist(
  Path=%sysfunc(getoption(SASINITIALFOLDER))\WorkspaceServer\PerfLogs,
/*  Path=C:\SAS\Config\Lev1\SASApp\WorkspaceServer\PerfLogs,*/
  Table=work.filer,
  Typefilter=log
  );
proc append base=work.perflogs data=filer;run;
/*Testing Only*/
/*options obs=1000;*/
data readlogs;
  set perflogs;
  where membername like 'arm4%'
    and Filesize > 0 and datepart(created)>="&dt_hist."d and entrytype ="File";
run;

/*******************************************************************************************
 * You may want to redirect the log if running interactively, depending on the number of
 * log files being read, the log window may run full because of the large number of files.
 *******************************************************************************************/
/*filename tmplog temp;*/
/*proc printto log=tmplog;run;*/


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
  create table arm_sessions as
    select distinct
      a.SessionDTTM,
      a.ProcessId,
      a.ApplicationName,
      a.Userid,
      a.Hostname,
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

/*Tidy up tables which are not needed now*/

proc datasets lib=work;
delete readlogs;
delete initrecord;
delete idrecord;
delete startrecord;
delete stoprecord;
delete updaterecord;
delete endrecord;
delete arm_steps;
run;
%mend;
%arm_log_read(history=10);
