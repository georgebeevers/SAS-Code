%macro workspace_Server_logs(outtbl=,history=);
/*Create a history macro */
	data _null_;
		call symput("dt_hist",PUT(intnx('day',today(),-&history),date9.));
	run;
/*Read in a list of the logs to extract information from*/
%getfilelist(
	Path=%sysfunc(getoption(SASINITIALFOLDER))\WorkspaceServer\AuditLogs,
	Table=work.filer,
	Typefilter=log
	);

proc append base=work.perflogs data=filer;
run;

/*Apply a history criteria to restrict the amount being read. Remove for a full read when */
/*implementing*/
data readlogs;
	set perflogs;
	where membername like 'data_audit%'
		and Filesize > 0 and datepart(created)>="&dt_hist."d and entrytype ="File";
run;

proc sql noprint;
	select fullname, count(*) into:audit_load1 - ,:obsnum TRIMMED
		from readlogs;
quit;

/*Loop over the available data*/
%put &obsnum;
	%do i=1 %to &obsnum;

		data _audit_data_log&i.;
			length /*model_name model_num serial os_name os_Version os_Release os_family $30.*/
			logname sysin Hostname DateTime Userid Action Status Libref Engine Member MemberType Openmode Path  Message $100. fullpath logfile $200.;
			format dttm datetime20. date date9. time time10.;
			infile "&&audit_load&i." dlm="|" missover   firstobs=2;
			input Hostname DateTime Userid Action Status Libref Engine Member MemberType Openmode Path;
			dttm = input(scan(_infile_,2,'|'),e8601dt23.3);
			date = datepart(input(scan(_infile_,2,'|'),e8601dt23.3));
			time = timepart(input(scan(_infile_,2,'|'),e8601dt23.3));
			fullpath=scan(_infile_,11,'|')||"\"||scan(_infile_,8,"|")||".sas7bdat";
			message=scan(_infile_,13,"|");
			logfile="&&audit_load&i.";
			PID=input(tranwrd(scan("&&audit_load&i.",7,"_"),".log"," "),8.);
			returncode=input(scan(_infile_,12,"|"),8.);
/*These can be added if needed but generally they are the same so should be obtained from the system rather than*/
/*writing it multiple times to the file*/
			/*			model_name=scan(_infile_,14,"|");*/
			/*			model_num=scan(_infile_,15,"|");*/
			/*			serial=scan(_infile_,16,"|");*/
			/*			os_name=scan(_infile_,17,"|");*/
			/*			os_version=scan(_infile_,18,"|");*/
			/*			os_release=scan(_infile_,19,"|");*/
			/*			os_family=scan(_infile_,20,"|");*/
/*Logname and SYSIN will be present for batch processing and will be captured where availabel. It will be missing for*/
/*users who operate with interactive sessions.*/
			logname=scan(_infile_,21,"|");
			sysin=scan(_infile_,22,"|");
		run;

	%end;

	/*Combine all temporary files into a final table*/
	data &outtbl.;
		set _audit_data:;
	run;

	/*Drop the temporary files*/
	proc datasets lib=work nolist;
		delete _audit_data:;
		delete readlogs;
	run;

%mend;

/*%load_data_audit_files(outtbl=work.data_audit_final,history=10);*/


