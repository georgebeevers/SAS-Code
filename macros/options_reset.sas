%macro options_reset(options=, options_id=, put=Y) / des = 'Reset an option to the value that was retained by OPTIONS_REMEMBER.';
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
			%put INFO: The options that will be recalled are "&_options_.".;
		%end;

	%*** Loop for each option.;
	%do _i_=1 %to &num_options.;

		%*** Set looped macro variables to be local to this macro to avoid conflicts.;
		%local option&_i_. string&_i_. result&_i_.;

		%*** Find the nth option in the string passed.;
		%let option&_i_.=%sysfunc(scan(&_options_.,&_i_.));

		%*** String will be populated with the option name wrapped with underscores.;
		%let string&_i_.=%sysfunc(compress(_&&option&_i_.._));

		%*** Test to see if the string exists as a macro variable.;
		%let result&_i_.=%symexist(&&string&_i_..);

		%*** If the macro variable does exist then there are 5 possible outcomes.;
		%if &&result&_i_..=1 %then
			%do;
				%*** Set additional looped macro variables to be local to this macro to avoid conflicts.;
				%local string_id&_i_. result_id&_i_.;

				%*** String id will be populated with the option name with "_id" as a suffix...;
				%*** ...and the entire string wrapped with underscores.;
				%let string_id&_i_.=%sysfunc(compress(_&&option&_i_.._id_));

				%*** Test to see if the string id exists as a macro variable.;
				%let result_id&_i_.=%symexist(&&string_id&_i_..);

				%*** If the value is tagged with an ID then
					do...;

						%if &&result_id&_i_..=1 %then
							%do;
								%*** Test whether the options id macro variable is populated.;
								%if %sysevalf(%superq(options_id)=,boolean) = 0 %then
									%do;
										%*** Outcome 1: The option is remembered with an ID and reset using the same ID.;
										%if &&&&&&string_id&_i_... = %superq(options_id) %then
											%do;
												%*** Reset the option to the original value.;
												options &&&&&&string&_i_...;

												%*** If the put flag is used, then put information to the log.;
												%if %sysfunc(upcase(&put.)) = Y %then
													%do;
														%put INFO: Option "&&option&_i_.." has been reset to "&&&&&&string&_i_...".;
													%end;

												%*** Once the option has been reset, we clear the global macro the option was stored in. ;             %symdel &&string&_i_..;             %symdel &&string_id&_i_..;
											%end;

										%*** Outcome 2: The option is remembered with an ID and reset using a different same ID.;
										%else
											%do;
												%*** If the put flag is used, then put information to the log.;
												%if %sysfunc(upcase(&put.)) = Y %then
													%do;
														%put INFO: Option "&&option&_i_.." has not been reset as the option ids do not match.;
													%end;
											%end;
									%end;

								%*** Outcome 3: The option is remembered with an ID and reset without an ID.;
								%else
									%do;
										%*** If the put flag is used, then put information to the log.;
										%if %sysfunc(upcase(&put.)) = Y %then
											%do;
												%put INFO: Option "&&option&_i_.." has not been reset as the option ids do not match.;
											%end;
									%end;
							%end;

						%*** If the value is not tagged with an ID then
							do...;
						%else
							%do;
								%*** Test whether the options id macro variable is populated.;
								%*** Outcome 4: The option is NOT remembered with an ID but is reset with an ID.;
								%if %sysevalf(%superq(options_id)=,boolean) = 0 %then
									%do;
										%*** If the put flag is used, then put information to the log.;
										%if %sysfunc(upcase(&put.)) = Y %then
											%do;
												%put INFO: Option "&&option&_i_.." has not been reset as the option ids do not match.;
											%end;
									%end;

								%*** Outcome 5: The option is NOT remembered with an ID and is NOT reset with an ID either.;
								%else
									%do;
										%*** Reset the option to the original value.;
										options &&&&&&string&_i_...;

										%*** If the put flag is used, then put information to the log.;
										%if %sysfunc(upcase(&put.)) = Y %then
											%do;
												%put INFO: Option "&&option&_i_.." has been reset to "&&&&&&string&_i_...".;
											%end;

										%*** Once the option has been reset, we clear the global macro the option was stored in. ;           %symdel &&string&_i_..;
									%end;
							%end;
			%end;
		%else
			%do;
				%*** If the put flag is used, then put information to the log.;
				%if %sysfunc(upcase(&put.)) = Y %then
					%do;
						%put INFO: Option "&&option&_i_.." does not have an associated macro variable available for reset.;
					%end;
			%end;
	%end;
%mend options_reset;