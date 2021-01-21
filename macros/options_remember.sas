%macro options_remember(options=, options_id=, put=Y) /  des = 'Record the current value for any options passed.';
	%*** Set macro variables to be local to this macro to avoid conflicts.;
	%local _i_ _options_ num_options;

	%*** Clean the input of any spurious spaces.;
	%let _options_=%sysfunc(strip(%sysfunc(compbl(&options.))));

	%*** Count how many options have been passed.;
	%let num_options=%sysfunc(countw(&_options_.));

	%*** If the put flag is used, then put information to the log.;
	%if %sysfunc(upcase(&put.)) = Y %then
		%do;
			%put INFO: There have been %sysfunc(strip(&num_options.)) options passed.;
			%put INFO: The options that will be remembered are "&_options_.".;
		%end;

	%*** Loop for each option.;
	%do _i_=1 %to &num_options.;

		%*** Set looped macro variables to be local to this macro to avoid conflicts.;
		%local option&_i_. string&_i_. result&_i_.;

		%*** Find the nth option in the string passed.;
		%let option&_i_.=%sysfunc(scan(&_options_.,&_i_.));

		%*** String will be populated with the option name wrapped with underscores.;
		%let string&_i_.=%sysfunc(compress(_&&option&_i_.._));

		%*** For each option, record the current value of the option.;
		%let result&_i_.=%sysfunc(getoption(&&option&_i_..));

		%*** If the value of the option is numeric then prefix the value with option name and =;
		%if %sysfunc(compress(%sysfunc(substr(%sysfunc(strip(&&result&_i_.)),1,1)),,kd)) ^= %then
			%do;
				%let result&_i_.=&&option&_i_.=&&result&_i_.;
			%end;

		%*** If the macro variable does not already exist then
			do...;

				%if %symexist(&&string&_i_..) = 0 %then
					%do;
						%*** Use string to generate a global macro variable...;
						%global &&string&_i_..;

						%*** ...that will contain the current value of the option;
						%let &&string&_i_..=&&result&_i_..;

						%*** Test whether the options id macro variable is populated.;
						%if %sysevalf(%superq(options_id)=,boolean) = 0 %then
							%do;
								%*** Set additional looped macro variables to be local to this macro to avoid conflicts.;
								%local string_id&_i_.;

								%*** String id will be populated with the option name with "_id" as a suffix...;
								%*** ...and the entire string wrapped with underscores.;
								%let string_id&_i_.=%sysfunc(compress(_&&option&_i_.._id_));

								%*** Use string id to generate a global macro variable...;
								%global &&string_id&_i_..;

								%*** ...that will contain the value of the options id;
								%let &&string_id&_i_..=%superq(options_id);
							%end;

						%*** If the put flag is used, then put information to the log.;
						%if %sysfunc(upcase(&put.)) = Y %then
							%do;
								%put INFO: Option "&&option&_i_.." has been remembered as "&&result&_i_..".;
								%put %str(     ) This value is stored in the global macro variable "&&string&_i_..".;

								%if %sysevalf(%superq(options_id)=,boolean) = 0 %then
									%do;
										%put %str(     ) This value is remembered with an options ID stored in the global macro variable "&&string_id&_i_..".;
									%end;
							%end;
					%end;
				%else
					%do;
						%*** If the put flag is used, then put information to the log.;
						%if %sysfunc(upcase(&put.)) = Y %then
							%do;
								%put INFO: Option "&&option&_i_.." has already been remembered with initial value "&&&&&&string&_i_...".;
								%put %str(     ) This value is stored in the global macro variable "&&string&_i_..".;
								%put %str(     ) To change the remembered value of "&&option&_i_.." the option must first be reset using "%nrstr(%%)options_reset(&&option&_i_..)".;
							%end;
					%end;
	%end;
%mend options_remember;