%macro sys_zip_member_delete(zip_fs=, zip_mem=);
	%put;
	%put INFO: zip_fs    = %superq(zip_fs);
	%put INFO: zip_mem   = %superq(zip_mem);

	%*** Assign the location of the zip file.;
	filename zip_fs "%superq(zip_fs)";

	%*** Specify the location of the zip file and name of the member.;
	filename zip_mem ZIP "%superq(zip_fs)" member="%superq(zip_mem)";

	%*** Check 1a: The zip file exists.;
	%if %sysfunc(fexist(zip_fs)) = 1 %then
		%do;
			%put CHECK: The zip file exists.;

			%*** Check 2a: The zip member exists.;
			%if %sysfunc(fexist(zip_mem)) = 1 %then
				%do;
					%put CHECK: The zip member exists.;

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

			%*** Check 2b: The zip member does NOT exist.;
			%else
				%do;
					%put CHECK: The zip member does NOT exist.;
				%end;
		%end;

	%*** Check 1b: The zip file does NOT exist.;
	%else
		%do;
			%put CHECK: The zip file does NOT exist.;
		%end;

	%*** Clear the file assignments;
	filename zip_fs clear;
	filename zip_mem clear;
%mend sys_zip_member_delete;
/*%sys_zip_member_delete(zip_fs=/home/sukgeb/cars.zip, zip_mem=cars.sas7bdat);*/