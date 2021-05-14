%macro sys_check_perm(path=, out_ref=work._check_permissions_output_) 
/ des = 'Use sys_ls recursively to check the permissions of a file or directory.';
	%*** Remember the current value of options prior to changing them. ;   
/*	%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); */
	options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

	%*** Define local macro variable(s).;
	%global z pos path_part path_dir;

	%*** Delete the temp table(s) that are appended to.;
	proc datasets lib=work nolist;
		delete       _check_permissions_base_;
	run;

	quit;

	%do z = 1 %to %eval(%sysfunc(countw(&path.,/))-0);

		%*** Find the positin of each /;
		data _null_;
			call scan("&path.",&z.,POS,LEN,"/");
			call symputx('pos',POS-1);
		run;
/* %end; */
		%let path_part=%substr(&path.,1,&pos.);
		%let path_dir=%scan(&path.,&z.,/);



		%if %sysfunc(fileexist(&path_part.))=1 %then
			%do;
				%*** List out the current directory / file in the path we are looping through. ;       
				%sys_ls(ls_path=&path_part., out_ref=work._check_permissions_dir_);
				%*** Only keep the relevant member.;
				data work._check_permissions_line_;
					set work._check_permissions_dir_;
					where scan(FileSpecification,-1,'/')="&path_dir.";
				run;

				%*** Append to a datastore so that we have all rows found.;
				proc append base = work._check_permissions_base_ data = work._check_permissions_line_;
				run;

			%end;
		%else
			%do;
				%put INFO: File Specification %superq(path_part) does NOT exist.;
				%goto leave;
			%end;
%end;

	%*** Give each row a number - this will be from 1 (first directory) to n (last directory or the file).;
	data work._check_permissions_n_;
		set work._check_permissions_base_ (keep=GroupName);
		n = _n_;
	run;

	%*** Grouping by group name we can find the top folder in a path where a group name is used.;
	proc sql;
		create table work._check_permissions_list_ as      
		select        
		GroupName,       
		min(n) as n     
		from work._check_permissions_n_     
		group by GroupName     
		order by n;
	quit;

	%*** Count the unique groups.;
	proc sql noprint;
		select count(*)      
		into :group_count     
		from work._check_permissions_list_;
	quit;

	%let group_count = %sysfunc(strip(&group_count.));

	%*** Read the groups into a macro variable array.;
	proc sql noprint;
		select GroupName      
		into:group_name1-:group_name&group_count.     
		from work._check_permissions_list_;
	quit;

	%*** Evaluate the effective permission for others by retaining groups from one row to the next.;
	data work._check_permissions_rw_ (drop=GroupNamePrior OtherName OtherNamePrior );
		set work._check_permissions_base_ (keep=FileSpecification ShortFileName OwnerName GroupName Type AccessPermission);
		by Type FileSpecification;
		length GroupNamePrior $32 OtherName $32 OtherNamePrior $32       
		%do z=1 %to &group_count.;
		&&group_name&z.. $2
		%end;

		Read $32       Write $32;
		retain GroupNamePrior OtherNamePrior;

		%*** Test if there are some read or write permission for "other";
		if strip(compress(substr(AccessPermission,8,2),'-')) ^= '' then
			do;
				%*** If the group name is the same for both rows and other has permissions then other is equal too...;
				%*** ...but if the group name is different across two rows then this implies other is the group from the row above.;
				if GroupName = GroupNamePrior then
					do;
						OtherName = OtherNamePrior;
					end;
				else if GroupName ^= GroupNamePrior then
					do;
						OtherName = GroupNamePrior;
					end;
			end;
		else
			do;
				OtherName = '';
			end;

		%*** Each group will have its own column in the ordered they are encountered in the path.;
		%*** The group column will contain any read or write permissions for the current path.;
		%do z=1 %to &group_count.;
			if GroupName = "&&group_name&z.." then
				&&group_name&z.. = strip(compress(substr(AccessPermission,5,2),'-'));
			else if OtherName = "&&group_name&z.." then
				&&group_name&z.. = strip(compress(substr(AccessPermission,8,2),'-'));
		%end;

		GroupNamePrior = GroupName;
		OtherNamePrior = OtherName;

		%*** Determine which is the first column with read (not write) and write (can be read too) permissions.;
		%do z=1 %to &group_count.;
			if Read = '' then
				do;
					if index(&&group_name&z..,'r') > 0 and index(&&group_name&z..,'w') = 0 then
						do;
							Read = "&&group_name&z..";
						end;
				end;

			if Write = '' then
				do;
					if index(&&group_name&z..,'r') > 0 and index(&&group_name&z..,'w') > 0 then
						do;
							Write = "&&group_name&z..";
						end;
				end;
		%end;

		%*** If we are not the last directory / file then we dont need write so read is write until it actually matters.;
		if Write = '' then
			do;
				if not last.type then
					do;
						Write = Read;
					end;
			end;
	run;

	%*** Count how many of the folders have a permission route compatible with read and write.;
	proc sql noprint;
		select        
		count(*) as row_count,       
		count(read) as read_count,       
		count(write) as write_count     
		into        
			:row_count,       
			:read_count,       
			:write_count     
		from work._check_permissions_rw_;
	quit;

	%*** Get the output names shorter for the sys_log_print macro call.;
	proc sql;
		create table work._check_permissions_print_ as      
		select        
			FileSpecification,       
			OwnerName as Owner,       
			GroupName as Group,       
			AccessPermission as Permissions     
		from work._check_permissions_rw_;
	quit;

	%*** Store just the last row in a dataset.;
	data work._check_permissions_last_;
		set work._check_permissions_print_ nobs=nobs;

		if _n_ = nobs then
			output;
	run;

	%*** Store certain fields in macro variables for outputting to the log when there are issues.;
	proc sql noprint;
		select        
			FileSpecification,       
			Owner,       
			Permissions     
			into       
				:FileSpecification,       
				:Owner,       
				:Permissions     
		from work._check_permissions_last_;
	quit;

	%*** Print the output to the log in a way that is easily readable. ;   
	%sys_log_print(in_ref=work._check_permissions_print_);
	%*** If all rows have a read value then print the effective read path.;
	%if &row_count. = &read_count. %then
		%do;

			proc sql;
				create table work._check_permissions_read_ (keep=Group) as        
					select distinct          
						b.GroupName as Group, 
					b.n       from work._check_permissions_rw_ as a       
				inner join work._check_permissions_list_ as b         
				on a.Read = b.GroupName       
				order by n;
			quit;

			%put INFO: To Read from "%sysfunc(strip(%superq(FileSpecification)))" you need the following groups:;

			%*** Print the output to the log in a way that is easily readable. ;     
		%sys_log_print(in_ref=work._check_permissions_read_);
		%end;
	%else
		%do;
			%put INFO: Unable to READ from "%sysfunc(strip(%superq(FileSpecification)))";
			%put INFO: Please contact the owner "%sysfunc(strip(%superq(Owner)))" regarding permissions "%sysfunc(strip(%superq(Permissions)))";
			%put;
		%end;

	%*** If all rows have a write value then print the effective write path.;
	%if &row_count. = &write_count. %then
		%do;

			proc sql;
				create table work._check_permissions_write_ (keep=Group) as        
			select distinct          
				b.GroupName as Group,         
				b.n       
			from work._check_permissions_rw_ as a       
			inner join work._check_permissions_list_ as b         
			on a.Write = b.GroupName       
			order by n;
			quit;

			%put INFO: To WRITE to "%sysfunc(strip(%superq(FileSpecification)))" you need the following groups:;

			%*** Print the output to the log in a way that is easily readable. ;     
		%sys_log_print(in_ref=work._check_permissions_write_);
		%end;
	%else
		%do;
			%put INFO: Unable to WRITE to "%sysfunc(strip(%superq(FileSpecification)))";
			%put INFO: Please contact the owner "%sysfunc(strip(%superq(Owner)))" regarding permissions "%sysfunc(strip(%superq(Permissions)))";
			%put;
		%end;

	%*** Create the output dataset related to out ref with appropriate columns that wont confuse the users.;
	proc sql;
		create table %superq(out_ref) as      select *     from work._check_permissions_rw_ (drop=read write);
	quit;

%leave:

	%*** Delete the temp table(s).;
	proc datasets lib=work nolist;
		delete       
		_check_permissions_base_       
		_check_permissions_dir_       
		_check_permissions_line_       
		_check_permissions_n_       
		_check_permissions_list_       
		_check_permissions_rw_       
		_check_permissions_print_       
		_check_permissions_last_       
		_check_permissions_max_       
		_check_permissions_read_       
		_check_permissions_write_;
	run;

	quit;

/*%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);*/
%mend sys_check_perm;

/*%sys_check_perm(path=/home/sukgeb/);*/









