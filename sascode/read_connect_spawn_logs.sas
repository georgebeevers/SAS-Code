/*Testing only - remove when complete*/
proc datasets lib=work;
delete _logs_connect;
run;


%macro connect_spawn_log_read(outtbl=);
/*Start of code*/

%getfilelist(
	Path=C:\SAS\Config\Lev1\ConnectSpawner\Logs\temp,
	Table=work._logs_connect,
	Typefilter=log
	);

data logs;
set _logs_connect;
/*where datepart(updated)<%sysfunc(today());*/
run;

proc sql;
	select fullname 
		into:connect_log1 - 
	from logs;
quit;
%do i=1 %to %get_obscnt(logs);

data _connect_spawner_log&i.;
	infile "&&connect_log&i." dlm=":" missover firstobs=3;
	length application $20. logname $200. user $100.;
	format dttm datetime20. date date9. time time10.;
	RETAIN application dttm date time  logname str user;
	input;
	application="BASE";
/*	Take only the ones which have been successful*/
	if find(_infile_,"successfully authenticated") then
		do;
			dttm = input(scan(_infile_,1,','),e8601dt23.3);
			date = datepart(input(scan(_infile_,1,'|'),e8601dt23.3));
			time = timepart(input(scan(_infile_,1,'|'),e8601dt23.3));
			str =_infile_;
			
		end;

/*		PID=input(scan(_infile_,14),8.);*/
/*		User=scan(scan(_infile_,7),2,"@");*/
	if find(_infile_,"PID") then
		do;
			PID=input(scan(_infile_,14),8.);
/*			output;*/
		end;
		if find(_infile_,"user ") and find(_infile_,"GBW") then
	do;
		user = compress(scan(scan(_infile_,8," ",'QR'),3," "),'"');
		output;
	end;

	logname="&&connect_log&i.";
run;
%end;
	/*Combine all temporary files into a final table*/
	data &outtbl.;
		set _connect_spawner_log:;
	run;

	/*Drop the temporary files*/
	proc datasets lib=work nolist;
		delete _connect_spawner_log:;
	run;

%mend;
%connect_spawn_log_read(outtbl=connect_server_logs);