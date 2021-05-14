%macro sys_log_print(in_ref=, in_keep=_all_) /  
			des = 'Print a dataset to the log in a readable format (max 256 characters).';
	%*** Remember the current value of options prior to changing them.;
/*	%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_log_print, put=N);*/
	options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

	%*** Define local macro variable(s).;
	%local y z;

	%if %sysfunc(exist(&in_ref.)) = 1 %then
		%do;
			%*** Get the contents for the specified columns;
			proc contents noprint  data = &in_ref. (keep=&in_keep.)       out = work._sys_log_print_contents_;
			run;

			%*** Order by varnum.;
			proc sort        data = work._sys_log_print_contents_;
				by varnum;
			run;

			%*** Count the number of columns.;
			proc sql noprint;
				select count(*)        
			into :sys_log_count       
			from work._sys_log_print_contents_;
			quit;

			%let sys_log_count = %sysfunc(strip(&sys_log_count.));

			%if &sys_log_count. > 0 %then
				%do;
					%*** Read the name of the variables into a macro variable array.;
					proc sql noprint;
						select            
							name,           
							type        
						into            
							:sys_log_name_1-:sys_log_name_&sys_log_count.,           
							:sys_log_type_1-:sys_log_type_&sys_log_count.         
						from work._sys_log_print_contents_;
					quit;

					%*** Determine the max utilised length for each variable.;
					proc sql;
						create table work._sys_log_max_ as          select

							%do y=1 %to &sys_log_count.;
								%if &y. > 1 %then
									%do;
										,
									%end;

								%if &&sys_log_type_&y.. = 1 %then
									%do;
										max(lengthn(compress(put(&&sys_log_name_&y..,32.)))) as sys_log_len&y.
									%end;
								%else %if &&sys_log_type_&y.. = 2 %then
									%do;
										max(lengthn(&&sys_log_name_&y..)) as sys_log_len&y.
									%end;
							%end;

						from &in_ref. (keep=&in_keep.);
					quit;

					%*** Determine the max length comparing the max utilised length and the header.;
					proc sql noprint;
						select

							%do y=1 %to &sys_log_count.;
								%if &y. > 1 %then
									%do;
										,
									%end;

								max(sys_log_len&y.,length(cats(upcase("&&sys_log_name_&y.."),':'))) as sys_log_len&y.
							%end;

						into

							%do y=1 %to &sys_log_count.;
								%if &y. > 1 %then
									%do;
										,
									%end;
								:sys_log_len&y.
							%end;

						from work._sys_log_max_;
					quit;

					%*** Strip out spaces in the length macro variables.;
					%do y=1 %to &sys_log_count.;
						%let sys_log_len&y. = %sysfunc(strip(&&sys_log_len&y..));
					%end;

					%*** Calculate the overall line length for all output.;
					%let sys_log_row=0;

					%do y=1 %to &sys_log_count.;
						%let sys_log_row = %eval(&sys_log_row. + &&sys_log_len&y.. + 3);
					%end;

					%let sys_log_row = %sysfunc(strip(&sys_log_row.));

					%*** Generate a string of dashes to match each variable.;
					%do y=1 %to &sys_log_count.;
						%let sys_log_dash&y.=;

						%do z=1 %to &&sys_log_len&y..;
							%let sys_log_dash&y.=&&sys_log_dash&y..-;
						%end;
					%end;

					%*** Create a dataset of dashes.;
					data work._sys_log_dashes_ (keep=_line_);
						length 
							_line_ $&sys_log_row.           
							%do y=1 %to &sys_log_count.;
						&&sys_log_name_&y.. $&&sys_log_len&y..
				%end;
			;
			%do y=1 %to &sys_log_count.;
				&&sys_log_name_&y.. = "&&sys_log_dash&y..";
			%end;

			_line_ = cat(           %do y=1 %to &sys_log_count.;             %if &y. > 1 %then

				%do;
					," | ",
				%end;

			&&sys_log_name_&y..
		%end;
	);
					run;

					%*** Create a dataset of headers.;
					data work._sys_log_header_ (keep=_line_);
						length            _line_ $&sys_log_row.           
							%do y=1 %to &sys_log_count.;
						&&sys_log_name_&y.. $&&sys_log_len&y..
						%end;
						;
						%do y=1 %to &sys_log_count.;
							&&sys_log_name_&y.. = upcase("&&sys_log_name_&y..:");
						%end;

						_line_ = cat(           
							%do y=1 %to &sys_log_count.;
							%if &y. > 1 %then

							%do;
								," | ",
							%end;

						&&sys_log_name_&y..
						%end;
						);
					run;

					%*** Create a dataset of data.;
					data work._sys_log_data_ /*(keep=_line_)*/;
						length            _line_ $&sys_log_row.           
							%do y=1 %to &sys_log_count.;
						sys_temp_&y. $&&sys_log_len&y..
						%end;
						;
						set &in_ref. (keep=&in_keep.);

						%do y=1 %to &sys_log_count.;
							%if &&sys_log_type_&y.. = 1 %then
								%do;
									sys_temp_&y. = compress(put(&&sys_log_name_&y..,32.));
								%end;
							%else %if &&sys_log_type_&y.. = 2 %then
								%do;
									sys_temp_&y. = &&sys_log_name_&y..;
								%end;
						%end;

						_line_ = cat(           %do y=1 %to &sys_log_count.;
							%if &y. > 1 %then

							%do;
								," | ",
							%end;

						sys_temp_&y.
						%end;
						);
					run;

					%put;

					%*** Print a row of dashes to the log.;
					data _null_;
						set work._sys_log_dashes_;
						put _line_;
					run;

					%*** Print a row for the header to the log.;
					data _null_;
						set work._sys_log_header_;
						put _line_;
					run;

					%*** Print a row of dashes to the log.;
					data _null_;
						set work._sys_log_dashes_;
						put _line_;
					run;

					%*** Print the data to the log.;
					data _null_;
						set work._sys_log_data_;
						put _line_;
					run;

					%*** Print a row of dashes to the log.;
					data _null_;
						set work._sys_log_dashes_;
						put _line_;
					run;

					%put;
%end;

					%*** Delete the temp table(s).;
					proc datasets lib=work nolist;
						delete         
							_sys_log_print_contents_         
							_sys_log_max_         
							_sys_log_dashes_         
							_sys_log_header_         
							_sys_log_data_;
					run;

					quit;

%end;

/*%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_log_print, put=N);*/
%mend sys_log_print;

