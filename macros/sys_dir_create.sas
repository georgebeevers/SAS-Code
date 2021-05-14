%macro sys_dir_create(path=, put=Y) /  
des = 'Use the dcreate function to recursively create a directory on the system.';
	%*** Make the macro_msg macro variable available globally;
	%global macro_msg;

	data _null_;
		length        new_path $512;

		%*** Count the number of occurrences of the directory break character ;     
		dirn = countw("%superq(path)",'/');
		%*** Loop for each directory;
		do i=1 to dirn;
			call scan("%superq(path)", i, POS, LEN, "/");

			%*** Define the full path of the parent directory;
			if POS-2 > 0 then
				parent_path = substr("%superq(path)", 1, POS-2);
			else parent_path = '/';

			%*** Define the name of the child directory (without full path) ;       
			dir = scan("%superq(path)", i, "/");
			%*** Define the full path of the child directory;
			if parent_path = '/' then
				child_path = cats(parent_path,dir);
			else child_path = cats(parent_path,'/',dir);

			%*** Test whether the parent and child paths exist ;       
			parent_exist = fileexist(parent_path);
			child_exist = fileexist(child_path);

			%*** If the parent directory exists but the child directory does not then
				do...;

					if parent_exist = 1 and child_exist = 1 then
						do;
							if "%superq(put)" = 'Y' then
								do;
									put 'Directory already exists: ' child_path;
								end;
						end;
					else if parent_exist = 1 and child_exist = 0 then
						do;
							if "%superq(put)" = 'Y' then
								do;
									put 'Directory does not exist. Creating now: ' child_path;
								end;

							%*** Step 1 : Perform command and get return code ;         
							new_path = dcreate(dir, parent_path);
							%*** Step 2 : Get system message ;         
							macro_msg = sysmsg();
							%*** Step 3 : Put the return code and system message into macro variables;
							call symput('macro_msg',strip(macro_msg));
						end;
					else if parent_exist = 0 then
						do;
							if "%superq(put)" = 'Y' then
								do;
									put 'Parent directory does not exist. Cannot create: ' parent_path;
								end;
						end;
				end;
	run;

	%*** If the put flag is used, then put information to the log.;
	%if %sysfunc(upcase(%superq(put))) = Y %then
		%do;
			%put %superq(macro_msg);
		%end;
%mend sys_dir_create;
/*%sys_dir_create(path=/home/sukgeb/one/two);*/