%macro sys_delete(path=, put=Y) /  
			des = 'Use the fdelete function to delete a file or dir on the system.';
	%*** Make the macro_rc and macro_msg macro variables available globally;
	%global macro_rc macro_msg;

	%*** Assign a file that you want to delete;
	filename _in_ "%superq(path)";

	data _null_;
		%*** Step 1 : Perform command and get return code ;      
		macro_rc = fdelete('_in_');
		%*** Step 2 : Get system message ;     
		macro_msg = sysmsg();
		%*** Step 3 : Put the return code and system message into macro variables;
		call symput('macro_rc',strip(put(macro_rc,8.)));
		call symput('macro_msg',strip(macro_msg));
	run;

	%*** Clear the file assignment;
	filename _in_ clear;

	%*** If the put flag is used, then put information to the log.;
	%if %sysfunc(upcase(%superq(put))) = Y %then
		%do;
			%put INFO: The macro return code is &macro_rc.;
			%put %superq(macro_msg);
		%end;
%mend sys_delete;
/*%sys_delete(path=/home/sukgeb/one/);*/