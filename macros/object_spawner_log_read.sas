/*Testing Options*/
/*Macro Needed = getfilelist.sas*/
/*options symbolgen mlogic mprint;*/
%macro load_data_audit_files(outtbl=,history=);
/*Get the SAS Config directory and create a date hisotry macro variable*/
	data _null_;
		folder="%sysfunc(getoption(SASINITIALFOLDER))";
		CALL SCAN( "%sysfunc(getoption(SASINITIALFOLDER))", -2, last_pos, last_length, '\', 'l');
		/*want = substrn( "%sysfunc(getoption(SASINITIALFOLDER))", 1, last_pos + last_length -1);*/
		call symput("sas_config",substrn( "%sysfunc(getoption(SASINITIALFOLDER))", 1, last_pos + last_length -1));
		call symput("dt_hist",PUT(intnx('day',today(),-&history.),date9.));
	run;

/*Check the macro variables*/
	%put &sas_config;
	%put &dt_hist.;
/*Read in a list of object spawner logs*/
	%getfilelist(
		Path=&sas_config.\ObjectSpawner\Logs,
		Table=work.filer,
		Typefilter=log
		);

	proc append base=work.perflogs data=filer;
	run;

/*Get a list of file to check based on the history requirement*/
	data readlogs;
		set perflogs;
		where membername like 'Object%'
			and Filesize > 0
			and datepart(created)>="&dt_hist."d and entrytype ="File";
	run;

	proc sql noprint;
		select fullname, count(*) into:audit_load1 - ,:obsnum TRIMMED
			from readlogs;
	quit;

	%put &audit_load1;
	%put &obsnum;
/*Loop over the data until complete*/
	%do i=1 %to &obsnum;

		data _obspawn_data_log&i.;
			infile "&&audit_load&i." dlm=":" missover firstobs=3;
			length application $20. logname $200.;
			format dttm datetime20. date date9. time time10.;
			RETAIN application dttm date time PID logname;
			input;

			if find(_infile_,"Launched process") then
				do;
					dttm = input(scan(_infile_,1,','),e8601dt23.3);
					date = datepart(input(scan(_infile_,1,'|'),e8601dt23.3));
					time = timepart(input(scan(_infile_,1,'|'),e8601dt23.3));
					PID=input(scan(_infile_,19),8.);
					output;
				end;

			if find(_infile_,"APPNAME") then
				do;
					application=scan(scan(_infile_,7,':'),2,"=");
					dttm = input(scan(_infile_,1,','),e8601dt23.3);
					date = datepart(input(scan(_infile_,1,'|'),e8601dt23.3));
					time = timepart(input(scan(_infile_,1,'|'),e8601dt23.3));
				end;
			logname="&&audit_load&i.";
		run;

	%end;

	/*Combine all temporary files into a final table*/
	data &outtbl.;
		set _obspawn_data_log:;
		where application not in ("ConnectionService 90"," ");
	run;

	/*Drop the temporary files*/
	proc datasets lib=work nolist;
		delete _obspawn_data_log:;
		delete readlogs;
		delete filer;
		delete perflogs;
	run;

%mend;

/*%load_data_audit_files(outtbl=work.obspawn_data_log2,history=20);*/
