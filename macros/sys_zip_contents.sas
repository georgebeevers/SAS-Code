%macro sys_zip_contents(zip_fs=, type=DATA, out_ref=work._zip_contents_output_);
	%put;
	%put INFO: zip_fs    = %superq(zip_fs);
	%put INFO: type      = %superq(type);
	%put INFO: out_ref   = %superq(out_ref);

	%*** Assign the location of the zip file.;
	filename zip_fs zip "%superq(zip_fs)";

	%*** Check 1a: The zip file exists.;
	%if %sysfunc(fexist(zip_fs)) = 1 %then
		%do;
			%put CHECK: The zip file exists.;

			%*** If any of the correct types are passed then gather the contents information.;
			%if %sysfunc(upcase(%superq(type))) = DATA or %sysfunc(upcase(%superq(type))) = LOG or %sysfunc(upcase(%superq(type))) = OUTPUT %then
				%do;
					%*** Read the list of members from the zip file.;
					data work._zip_contents_ (keep=memname);
						length memname $512;
						fid=dopen("zip_fs");

						if fid=0 then
							stop;
						memcount=dnum(fid);

						do i=1 to memcount;
							memname=dread(fid,i);
							output;
						end;

						rc=dclose(fid);
					run;

				%end;

			*** If the type is DATA then output to the specified output reference.;
			%if %sysfunc(upcase(%superq(type))) = DATA %then
				%do;

					data %superq(out_ref);
						set work._zip_contents_;
					run;

				%end;

			%*** If the type is LOG then print the information to the log.;
			%else %if %sysfunc(upcase(%superq(type))) = LOG %then
				%do;

					data _null_;
						set work._zip_contents_;
						put (_all_)( = );
					run;

				%end;

			%*** If the type is OUTPUT then print the information to the results / output window.;
			%else %if %sysfunc(upcase(%superq(type))) = OUTPUT %then
				%do;

					proc print         data = work._zip_contents_;
						var _all_;
					run;

				%end;

			%*** Otherwise put an (ER)ROR to the log.;
			%else
				%do;
					%put %str(ER)ROR: The only valid values for "type" are "DATA", "LOG" and "OUTPUT";
				%end;
		%end;

	%*** Check 1b: The zip file does NOT exist.;
	%else
		%do;
			%put CHECK: The zip file does NOT exist.;
		%end;

	%if %sysfunc(exist(work._zip_contents_)) %then
		%do;
			%*** Delete the temp table(s).;
			proc datasets lib=work nolist;
				delete          _zip_contents_;
			run;

			quit;

		%end;

	%*** Clear the file assignments;
	filename zip_fs clear;
%mend sys_zip_contents;

/*%sys_zip_contents(zip_fs=/home/sukgeb/cars.zip, type=DATA, out_ref=work._zip_contents_output_);*/