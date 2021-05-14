%macro sys_find(find_path=, max_depth=, format=L, out_ref=work._find_output_, put=N) 
/  des = 'Use various functions to mimic the recursive listing of a directory on the system.';
	%*** Remember the current value of options prior to changing them. ;   
/*%options_remember(options=mlogic mprint notes symbolgen, options_id=sys_find, put=N);*/
	options nomlogic nomprint nosymbolgen nonotes;

	%*** Define local macro variable(s).;
	%local dsopt where_max_depth dir_count loop_count directory depth;

	%*** Dataset options that allow the process to run faster.;
	%let dsopt = COMPRESS=NO;

	%*** Determine and handle if the max_depth parameter is being used.;
	%if %sysfunc(compress(%superq(max_depth),,kd)) = %superq(max_depth)    and %sysevalf(%superq(max_depth)=,boolean) = 0 %then
		%do;
			%let where_max_depth = where depth le %superq(max_depth);
		%end;
	%else
		%do;
			%let where_max_depth =;
		%end;

	%*** Clear down any pre-existing work tables that we append to.;
	proc datasets lib=work nolist;
		delete       _FIND_CHECKED_       _FIND_LISTING_       _FIND_UNCHECKED_;
	run;

	quit;

	%*** Create the base unchecked table using the find path.;
	data WORK._FIND_UNCHECKED_ (&dsopt.);
		length FileSpecification $512 Depth 8.;

		if length("%superq(find_path)") = 1 or substr("%superq(find_path)",length("%superq(find_path)"),1) ^= '/' then
			do;
				FileSpecification = "%superq(find_path)";
			end;
		else
			do;
				FileSpecification = substr("%superq(find_path)",1,length("%superq(find_path)")-1);
			end;

		Depth = 0;
	run;

	%*** Set a default value of the Directory Count to 1 (because we start with 1 directory).;
	%let dir_count = 1;
	%let loop_count = 0;

	%*** 1.0.4 - If the put flag is used, then put information to the log.;
	%if %sysfunc(upcase(%superq(put))) = Y %then
		%do;
			%put;
			%put Start of find loop...;
			%put;
		%end;

	%*** Continue to loop as long as there are additional directories to explore.;
	%do %while (&dir_count. > 0);

		%*** Define the first row as the next directory to examine.;
		%*** All other rows remain in the unchecked directory list (grows as process loops).;
		data        WORK._FIND_NEXT_ (&dsopt.)        WORK._FIND_UNCHECKED_ (&dsopt.);
			set WORK._FIND_UNCHECKED_;

			if _n_ = 1 then
				output _FIND_NEXT_;
			else output _FIND_UNCHECKED_;
		run;

		%*** Put the values for the current directory into macro variables.;
		proc sql noprint;
			select          
				FileSpecification,         
			Depth       into          
			:Directory,         
			:Depth        
		from WORK._FIND_NEXT_;
		quit;

		%let Loop_Count = %eval(&loop_count. + 1);

		%*** 1.0.4 - If the put flag is used, then put information to the log.;
		%if %sysfunc(upcase(%superq(put))) = Y %then
			%do;
				%put &loop_count. : %superq(directory);
			%end;

		%*** Perform a listing on the current directory. ;     
		%sys_ls(ls_path=%superq(directory), format=%sysfunc(upcase(%superq(format))));
		%*** Append the directory that was just checked into the checked list.;
		proc append       base = WORK._FIND_CHECKED_       data = WORK._FIND_NEXT_;
		run;

		%*** Define the depth for new items being added to the list of found objects.;
		proc sql;
			create table WORK._FIND_NEW_LISTING_ as        
			select a.*       
			from          (         select *, 
				case             
					when FileSpecification = "%superq(directory)"                then &depth.               
					else &depth. + 1            
				end 
			as Depth         from WORK._LS_OUTPUT_         ) as a       %superq(where_max_depth);
		quit;

		%*** Append the new objects to the overall list.;
		proc append       base = WORK._FIND_LISTING_       data = WORK._FIND_NEW_LISTING_;
		run;

		%*** Define the items which we need to add to the unchecked list.;
		proc sql;
			create table WORK._FIND_NEW_UNCHECKED_ as        
			select          
			a.FileSpecification,         
			a.Depth       
		from WORK._FIND_NEW_LISTING_ as a       
		left join WORK._FIND_CHECKED_ as b         
		on a.FileSpecification = b.FileSpecification       
		left join WORK._FIND_UNCHECKED_ as c         
		on a.FileSpecification = c.FileSpecification       
		where a.Type = 'd'         
		and b.FileSpecification = ''         
		and c.FileSpecification = '';
		quit;

		%*** Append the items to the unchecked list.;
		proc append       base = WORK._FIND_UNCHECKED_       data = WORK._FIND_NEW_UNCHECKED_;
		run;

		%*** Count how many directories are left to be checked.;
		proc sql noprint;
			select count(*) into: Dir_Count        from WORK._FIND_UNCHECKED_;
		quit;

	%end;

	%*** 1.0.4 - If the put flag is used, then put information to the log.;
	%if %sysfunc(upcase(%superq(put))) = Y %then
		%do;
			%put;
			%put End of find loop...;
			%put;
		%end;

	%*** Create a final ordered output with distinct rows.;
	proc sql;
		create table %superq(out_ref) as      select distinct *     from WORK._FIND_LISTING_ 
			order by FileSpecification;
	quit;

	%*** Delete the temp table(s).;
	proc datasets lib=work nolist;
		delete        
		_LS_OUTPUT_       
		_FIND_NEXT_       
		_FIND_CHECKED_       
		_FIND_NEW_LISTING_       
		_FIND_LISTING_       
		_FIND_NEW_UNCHECKED_       
		_FIND_UNCHECKED_;
	run;

	quit;

	%*** Reset the options to their original stored values. ;   
/*	%options_reset(options=mlogic mprint notes symbolgen, options_id=sys_find, put=N);*/
%mend sys_find;
/*%sys_find(find_path=/home/sukgeb);*/