%macro sys_file_copy(path=, newpath=, put=Y,permis_chg_in=) /  
			des = 'Use the fread, fget, fput and fwrite functions to copy a file on the system.';
	%*** Make the macro_rc and macro_msg macro variables available globally;
	%global macro_rc macro_msg;

	/* Allow permissions to be changed on the copied file */
	%if %length(&permis_chg_in)>0 %then
		%do;
			%let permission_change=permission=&permis_chg_in.;
			%put INFO: New_Permissions_Set=&permission_change;
		%end;
	%else
		%do;
			%let permission_change=;
			%put INFO: Permissions Not Changed;
		%end;

	%*** Assign the source and target files;
	filename _in_ "%superq(path)";
	filename _out_ "%superq(newpath)" &permission_change.;

	%*** Copy the file byte-for-byte;
	data _null_;
		length filein 8 fileout 8;

		%*** Step 1 : Perform commands and get the return code;
		filein = fopen('_in_','I',1,'B');
		fileout = fopen('_out_','O',1,'B');
		rec = '20'x;

		do while(fread(filein)=0);
			macro_rc = fget(filein,rec,1);
			macro_rc = fput(fileout,rec);
			macro_rc = fwrite(fileout);
		end;

		macro_rc = fclose(filein);
		macro_rc = fclose(fileout);

		%*** Step 2 : Get system message;
		macro_msg = sysmsg();

		%*** Step 3 : Put the return code and system message into macro variables;
		call symput('macro_rc',strip(put(macro_rc,8.)));
		call symput('macro_msg',strip(macro_msg));
	run;

	%*** Clear the file assignments;
	filename _in_ clear;
	filename _out_ clear;

	%*** If the put flag is used, then put information to the log.;
	%if %sysfunc(upcase(%superq(put))) = Y %then
		%do;
			%put INFO: The macro return code is &macro_rc.;
			%put %superq(macro_msg);
		%end;
%mend sys_file_copy;

/*%sys_file_copy(path=/home/sukgeb/sas_conf.sh,newpath=/home/sukgeb/one/sas_conf.sh);*/
/*%sys_file_copy(path=/home/sukgeb/sas_conf.sh,newpath=/home/sukgeb/one/sas_conf.sh,permis_chg_in='A::u::rwx,A::g::r-x,A::o::---');*/
/* permissions='A::u::rwx,A::g::r-x,A::o::---' */