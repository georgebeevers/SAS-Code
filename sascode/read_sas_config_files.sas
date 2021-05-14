/*Create observation count macro*/
%macro get_obscnt(dsn);
	%local nobs dsnid;
	%let nobs=.;

	%* Open the data set of interest;
	%let dsnid = %sysfunc(open(&dsn));

	%* If the open was successful get the;
	%* number of observations and CLOSE &dsn;
	%if &dsnid %then
		%do;
			%let nobs=%sysfunc(attrn(&dsnid,nlobs));
			%let rc  =%sysfunc(close(&dsnid));
		%end;
	%else
		%do;
			%put Unable to open &dsn - %sysfunc(sysmsg());
		%end;

	%* Return the number of observations;
	&nobs
%mend get_obscnt;
/*Maacro for getting all CFG file contents*/
%macro read_sas_cfg();

	proc sql;
		create table _ds_options as 
			select optname
				/*,setting */

		/*Set to 10 - a macro loop would be better */
		/*We can exlude any missing ones later*/
		,scan(setting,2," ",'QR') as CFG1
		,scan(setting,3," ",'QR') as CFG2
		,scan(setting,4," ",'QR') as CFG3
		,scan(setting,5," ",'QR') as CFG4
		,scan(setting,6," ",'QR') as CFG5
		,scan(setting,7," ",'QR') as CFG6
		,scan(setting,8," ",'QR') as CFG7
		,scan(setting,9," ",'QR') as CFG8
		,scan(setting,10," ",'QR') as CFG9
		,scan(setting,11," ",'QR') as CFG10

		from dictionary.options
			where optname="CONFIG";
	quit;

	/*Transpose Data*/
	proc transpose data=_ds_options out=_ds_options_trans (rename=(col1=option_name));
		VAR CFG:;
	run;

	data _keep;
		set _ds_options_trans;
		where length(option_name)>10;
	run;

	proc datasets lib=work;
		delete _ds_options_trans;
	run;

	proc sql;
		select option_name into: optname1 -
			from _keep;
	quit;


%do i=1 %to %get_obscnt(_keep);

	data _config_read&i.;
		length CFGLOC $300. FULL_LINE $2000.;
		infile "&&optname&i."   truncover lrecl=32767;
		input;
		FULL_LINE=compress(_infile_, '09'x);
		CFGLOC="&&optname&i.";
	run;

%end;

/*Stack all files and delete temps*/
data SAS_CFGS;
	set _config_read:;
run;

proc datasets lib=work;
	delete _:;
run;

%mend;

%read_sas_cfg;