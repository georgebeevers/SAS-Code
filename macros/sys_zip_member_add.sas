%macro sys_zip_member_add(fs=, zip_fs=, zip_mem=, overwrite=N, delete=N);
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
	%let zip_dir = %sysfunc(substr(%superq(zip_fs),1,%sysfunc(length(%superq(zip_fs)))-%sysfunc(length(%sysfunc(scan(%superq(zip_fs),-1,"/"))))-1));

	%*** Assign the current location of the file.;
	filename fs "%superq(fs)";

	%*** Assign the location of the parent directory where the zip folder is or will be created.;
	filename zip_dir "%superq(zip_dir)";

	%*** Assign the location of the zip file.;
	filename zip_fs "%superq(zip_fs)";

	%*** Assign the location of the zip file and name of the member.;
	filename zip_mem zip "%superq(zip_fs)" member="%superq(zip_mem)";

	%*** Check 1a: The file does exist and the zip parent directory does exist.;
	%if %sysfunc(fexist(fs)) = 1 and %sysfunc(fexist(zip_dir)) = 1 %then
		%do;
			%put CHECK: The file does exist and the zip parent directory does exist.;

			%*** Check 2a: The overwrite option is set to N which requires further checks.;
			%if %sysfunc(upcase(%superq(overwrite))) = N %then
				%do;
					%put CHECK: The overwrite option is set to N which requires further checks.;

					%*** Check 3a: The zip file already exists which requires further checks.;
					%if %sysfunc(fexist(zip_fs)) = 1 %then
						%do;
							%put CHECK: The zip file already exists which requires further checks.;

							%*** Check 4a: The zip member already exists and overwrite is preventing replacement.;
							%if %sysfunc(fexist(zip_mem)) = 1 %then
								%do;
									%let exe_cmd = 0;
									%put CHECK: The zip member already exists and overwrite flag is preventing replacement.;
								%end;

							%*** Check 4b: The zip member does not already exist.;
							%else
								%do;
									%put CHECK: The zip member does not already exist.;
								%end;
						%end;

					%*** Check 3b: The zip file does not already exist.;
					%else
						%do;
							%put CHECK: The zip file does not already exist.;
						%end;
				%end;

			%*** Check 2b: The overwrite option is set to Y which requires no further checks.;
			%else %if %sysfunc(upcase(%superq(overwrite))) = Y %then
				%do;
					%put CHECK: The overwrite option is set to Y which requires no further checks.;
				%end;

			%*** Check 2c: The overwrite option is not set to Y or N.;
			%else
				%do;
					%let exe_cmd = 0;
					%put CHECK: The overwrite option is not set to Y or N.;
				%end;
		%end;

	%*** Check 1b: The file does not exist and the zip parent directory does exist.;
	%else %if %sysfunc(fexist(fs)) = 0 and %sysfunc(fexist(zip_dir)) = 1 %then
		%do;
			%let exe_cmd = 0;
			%put CHECK: The file does not exist and the zip parent directory does exist.;
		%end;

	%*** Check 1c: The file does exist and the zip parent directory does not exist.;
	%else %if %sysfunc(fexist(fs)) = 1 and %sysfunc(fexist(zip_dir)) = 0 %then
		%do;
			%let exe_cmd = 0;
			%put CHECK: The file does exist and the zip parent directory does not exist.;
		%end;

	%*** Check 1d: The file does not exist and the zip parent directory does not exist.;
	%else %if %sysfunc(fexist(fs)) = 0 and %sysfunc(fexist(zip_dir)) = 0 %then
		%do;
			%let exe_cmd = 0;
			%put CHECK: The file does not exist and the zip parent directory does not exist.;
		%end;

	%*** Outcome 1a: Command will execute.;
	%if %superq(exe_cmd) = 1 %then
		%do;
			%*** Copy the file into the zip file member byte-by-byte;
			data _null_;
				infile fs recfm=n;
				file zip_mem recfm=n;
				input byte $char1. @;
				put byte $char1. @;
			run;

			%*** Outcome 2a: Member has been successfully added to zip file.;
			%if %sysfunc(fexist(zip_mem)) = 1 %then
				%do;
					%put OUTCOME: Member has been added to zip file.;

					%*** Only do the next section if the macro is set to delete the original after adding the member.;
					%if %sysfunc(upcase(%superq(delete))) = Y %then
						%do;

							data _null_;
								rc = fdelete('fs');

								if rc=0 then
									do;
										put "DELETE: Successfully deleted %superq(fs).";
									end;
								else
									do;
										put "DELETE: Unable to delete %superq(fs).";
									end;
							run;

						%end;
					%else
						%do;
							%put DELETE: Delete flag is preventing deletion of %superq(fs).;
						%end;
				%end;

			%*** Outcome 2b: Member has NOT been successfully added to zip file.;
			%else
				%do;
					%put OUTCOME: Member has NOT been successfully added to zip file.;
				%end;
		%end;

	%*** Outcome 1b: Command will NOT execute due to failed checks.;
	%else
		%do;
			%put OUTCOME: Command will NOT execute due to failed checks.;
		%end;

	%*** Clear the file assignments;
	filename fs clear;
	filename zip_dir clear;
	filename zip_fs clear;
	filename zip_mem clear;
%mend sys_zip_member_add;

/*%sys_zip_member_add(fs=/home/sukgeb/cars.sas7bdat, zip_fs=/home/sukgeb/cars.zip, zip_mem=cars.sas7bdat, overwrite=Y, delete=N);*/