%macro sys_zip_member_extract(fs=, zip_fs=, zip_mem=, overwrite=N, delete=N);
	%put;
	%put INFO: fs        = %superq(fs);
	%put INFO: zip_fs    = %superq(zip_fs);
	%put INFO: zip_mem   = %superq(zip_mem);
	%put INFO: overwrite = %superq(overwrite);
	%put INFO: delete    = %superq(delete);

	%*** Set macro variables to be local to this macro to avoid conflicts.;
	%local exe_cmd zip_dir;

	%*** Give execute command a default value of 1.;
	%let exe_cmd = 1;

	%*** Define the parent directory where the zip folder is or will be created.;
	%let fs_dir = %sysfunc(substr(%superq(fs),1,%sysfunc(length(%superq(fs)))-%sysfunc(length(%sysfunc(scan(%superq(fs),-1,"/"))))-1));

	%*** Assign the location of the output directory.;
	filename fs_dir "%superq(fs_dir)";

	%*** Assign the location of the output file.;
	filename fs "%superq(fs)";

	%*** Assign the location of the zip file.;
	filename zip_fs "%superq(zip_fs)";

	%*** Assign the location of the zip file and name of the member.;
	filename zip_mem zip "%superq(zip_fs)" member="%superq(zip_mem)";

	%*** Check 1a: The output file directory does exist and the zip file does exist.;
	%if %sysfunc(fexist(fs_dir)) = 1 and %sysfunc(fexist(zip_fs)) = 1 %then
		%do;
			%put CHECK: The output file directory does exist and the zip file does exist.;

			%*** Check 2a: The zip member does exist.;
			%if %sysfunc(fexist(zip_mem)) = 1 %then
				%do;
					%put CHECK: The zip member does exist.;

					%*** Check 3a: The overwrite option is set to N which requires further checks.;
					%if %sysfunc(upcase(%superq(overwrite))) = N %then
						%do;
							%put CHECK: The overwrite option is set to N which requires further checks.;

							%*** Check 4a: The output file already exists and overwrite is preventing replacement.;
							%if %sysfunc(fexist(fs)) = 1 %then
								%do;
									%let exe_cmd = 0;
									%put CHECK: The output file already exists and overwrite is preventing replacement.;
								%end;

							%*** Check 4b: The output file does not already exist.;
							%else
								%do;
									%put CHECK: The output file does not already exist.;
								%end;
						%end;

					%*** Check 3b: The overwrite option is set to Y which requires no further checks.;
					%else %if %sysfunc(upcase(%superq(overwrite))) = Y %then
						%do;
							%put CHECK: The overwrite option is set to Y which requires no further checks.;
						%end;

					%*** Check 3c: The overwrite option is not set to Y or N.;
					%else
						%do;
							%let exe_cmd = 0;
							%put CHECK: The overwrite option is not set to Y or N.;
						%end;
				%end;

			%*** Check 2b: The zip member does not exist.;
			%else
				%do;
					%let exe_cmd = 0;
					%put CHECK: The zip member does not exist.;
				%end;
		%end;

	%*** Check 1b: The output file directory does not exist and the zip file does exist.;
	%else %if %sysfunc(fexist(fs_dir)) = 0 and %sysfunc(fexist(zip_fs)) = 1 %then
		%do;
			%let exe_cmd = 0;
			%put CHECK: The output file directory does not exist and the zip file does exist.;
		%end;

	%*** Check 1c: The output file directory does exist and the zip file does not exist.;
	%else %if %sysfunc(fexist(fs_dir)) = 1 and %sysfunc(fexist(zip_fs)) = 0 %then
		%do;
			%let exe_cmd = 0;
			%put CHECK: The output file directory does exist and the zip file does not exist.;
		%end;

	%*** Check 1d: The output file directory does not exist and the zip file does not exist.;
	%else %if %sysfunc(fexist(fs_dir)) = 0 and %sysfunc(fexist(zip_fs)) = 0 %then
		%do;
			%let exe_cmd = 0;
			%put CHECK: The output file directory does not exist and the zip file does not exist.;
		%end;

	%*** Outcome 1a: Command will execute.;
	%if %superq(exe_cmd) = 1 %then
		%do;
			%*** Copy the file out of the zip file in blocks.;
			data _null_;
				infile zip_mem lrecl=256 recfm=F length=length eof=eof unbuf;
				file fs lrecl=256 recfm=N;
				input;
				put _infile_ $varying256. length;
				return;
		eof:
				stop;
			run;

			%*** Outcome 2a: Member has been successfully extracted to output file.;
			%if %sysfunc(fexist(fs)) = 1 %then
				%do;
					%put OUTCOME: Member has been successfully extracted to output file.;

					%*** Only do the next section if the macro is set to delete the original zip member after extracting it.;
					%if %sysfunc(upcase(%superq(delete))) = Y %then
						%do;
							%*** Delete the zip member.;
							data _null_;
								rc = fdelete('zip_mem');

								if rc=0 then
									do;
										put "DELETE: Successfully deleted zip member %superq(zip_mem).";
									end;
								else
									do;
										put "DELETE: Unable to delete zip member %superq(zip_mem).";
									end;
							run;

						%end;
					%else
						%do;
							%put DELETE: Delete flag is preventing deletion of %superq(zip_mem).;
						%end;
				%end;

			%*** Outcome 2b: Member has NOT been successfully extracted to output file.;
			%else
				%do;
					%put OUTCOME: Member has NOT been successfully extracted to output file.;
				%end;
		%end;

	%*** Outcome 1b: Command will NOT execute due to failed checks.;
	%else
		%do;
			%put OUTCOME: Command will NOT execute due to failed checks.;
		%end;

	%*** Clear the file assignments;
	filename fs_dir clear;
	filename fs clear;
	filename zip_fs clear;
	filename zip_mem clear;
%mend sys_zip_member_extract;

/*%sys_zip_member_extract(fs=/home/sukgeb/cars.sas7bdat, zip_fs=/home/sukgeb/cars.zip, zip_mem=cars.sas7bdat, overwrite=Y, delete=N);*/

