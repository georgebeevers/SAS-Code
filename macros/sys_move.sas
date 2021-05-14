%macro sys_move(path=, newpath=, put=Y) /  
			des = 'Use the rename function to rename or move a file on the system.';
	%*** Make the macro_rc and macro_msg macro variables available globally;
	%global macro_rc macro_msg;

	data _null_;
		%*** Step 1 : Perform command and get return code ;       
		macro_rc = rename("%superq(path)", "%superq(newpath)", 'file');
		%*** Step 2 : Get system message ;     macro_msg = sysmsg();
		%*** Step 3 : Put the return code and system message into macro variables;
		call symput('macro_rc',strip(put(macro_rc,8.)));
		call symput('macro_msg',strip(macro_msg));
	run;

	%*** If the put flag is used, then put information to the log.;
	%if %sysfunc(upcase(%superq(put))) = Y %then
		%do;
			%put INFO: The macro return code is &macro_rc.;
			%put %superq(macro_msg);
		%end;
%mend sys_move;
/*%sys_move(path=/home/sukgeb/sas_conf.sh,newpath=/home/sukgeb/one/two/sas_conf.sh);*/
