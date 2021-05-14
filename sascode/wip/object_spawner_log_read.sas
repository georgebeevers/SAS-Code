/*Macros Needed*/
/*%get_obscnt*/
/*%getfilelist*/
/*Testing Options*/
/*options symbolgen mlogic mprint;*/
%macro object_spawner_logs(outtbl=,cfg_path=);
	/*Read in a list of object spawner logs*/
	%getfilelist(
		Path=&cfg_path.,
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
			and entrytype ="File";
	run;

	proc sql noprint;
		select fullname, count(*) into:audit_load1 - ,:obsnum TRIMMED
			from readlogs;
	quit;

	%put &audit_load1;
	%put &obsnum;

	/*Loop over the data until complete*/
	%do i=1 %to %get_obscnt(readlogs);

		data _obspawn_data_log&i. (drop=x);
			infile "&&audit_load&i." dlm=":" missover firstobs=3;
			length application $100. user $100. logname   $200. line  $32000;
			format dttm datetime20. date date9. time time10.;
			RETAIN application dttm date time /*PID*/
			logname /*line p l*/
			;
			input;

			/*Find all APPNAME= and then extract the application which made the connection*/
			if find(_infile_,"APPNAME") then
				do;
					x = tranwrd(scan(_infile_,2,"=","QR"),".","");
					if Not Missing(x) and x ^= '0' then
						application = x;
					else application = " ";
					dttm = input(scan(_infile_,1,','),e8601dt23.3);
					date = datepart(input(scan(_infile_,1,'|'),e8601dt23.3));
					time = timepart(input(scan(_infile_,1,'|'),e8601dt23.3));
					x = scan(scan(_infile_,4,":"),1," ","QR");
					if Not Missing(x) and x ^= '0' then
						user = x;
					else user = "Unknown";
					output;
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
%object_spawner_logs(outtbl=work.object_spawner_data,cfg_path=C:\temp\SAS_Data\M_HSBC\objectspawner);