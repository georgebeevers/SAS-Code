%macro sys_ls(ls_path, format=L, out_ref=work._ls_output_) / 
		des='Use various functions to mimic the listing of a directory on the system.';
	%*** Remember the current value of options prior to changing them.;

	/*%lamp_options_remember(options=mlogic mprint notes symbolgen, options_id=sys_ls, put=N);*/
	options nomlogic nomprint nonotes nosymbolgen;
	%*** Define local macro variable(s).;
	%local keep dsopt;
	%*** Dataset options that allow the process to run faster.;
	%let dsopt = COMPRESS=NO;
	%*** Create the base transient table using the ls_path.;

	data WORK._LS_NEXT_ (&dsopt.);
		length FileSpecification $512;

		if length("%superq(ls_path)")=1 or substr("%superq(ls_path)", 
			length("%superq(ls_path)"), 1) ^='/' then
				do;
				FileSpecification="%superq(ls_path)";
			end;
		else
			do;
				FileSpecification=substr("%superq(ls_path)", 1, 
					length("%superq(ls_path)")-1);
			end;
	run;

	%*** In order to avoid file-lock errors in log, route log to black hole.;

	proc printto log="/dev/null";
	run;

	%*** List all child files and child directories within a parent directory.;

	data WORK._LS_LISTING_       (keep=FileSpecification MemberName OwnerName 
			GroupName AccessPermission FileSize LastModified Readable SysMsg &dsopt.);
		set WORK._LS_NEXT_ (keep=FileSpecification);
		length pref $8 cref $8 OwnerName $32 GroupName $32 AccessPermission $12 
			Filesize 8. LastModified $48 Readable $1 SysMsg $512;
		%*** Assign a file reference to the parent directory.;
		rc1=filename(pref, FileSpecification);
		%*** 
		If the file assignment was successful then
			try and open the parent directory.;
		%*** (NO)TE: File assignments are often successful in undesirable situations.;

		if rc1=0 then
			do;
				pid=dopen(pref);
				%*** Store any system message i.e.;
				%*** (ER)ROR: Physical file does not exist, /.../.../...;
				%*** (ER)ROR: Insufficient authorization to access /.../.../...;
				SysMsg=sysmsg();
			end;
		else
			do;
				pid=.;
			end;
		%*** Clear the file assignment as we are now using the pid variable.;
		rc2=filename(pref);
		%*** 
		If opening the parent directory was unsuccessful then
			output.;

		if pid <=0 then
			do;
				%*** -------------------------------------------------------------------;
				%*** OUTPUT BLOCK 1 - Failed to read parent directory.;
				%*** -------------------------------------------------------------------;
				OwnerName='';
				GroupName='';
				AccessPermission='';
				FileSize=.;
				LastModified='';
				Readable='N';
				output;
			end;
		%*** 
		If opening the parent directory was successful then
			gather additional information.;
		else
			do;
				%*** -------------------------------------------------------------------;
				%*** OUTPUT BLOCK 2 - Successfully read parent directory.;
				%*** -------------------------------------------------------------------;
				OwnerName=dinfo(pid, 'Owner Name');
				GroupName=dinfo(pid, 'Group Name');
				AccessPermission=dinfo(pid, 'Access Permission');
				FileSize=.;
				LastModified=dinfo(pid, 'Last Modified');
				Readable='Y';
				output;
				%*** Determine the number of child members in the parent directory.;
				dnum=dnum(pid);
				%*** Loop for each child member of the parent directory.;

				do i=1 to dnum;
					%*** Determine the name of the current child member (file or directory).;
					MemberName=dread(pid, i);
					%*** Define the file specification using the parent directory and child 
						member name.;

					if dinfo(pid, 'Directory')='/' then
						do;
							FileSpecification=cats(dinfo(pid, 'Directory'), MemberName);
						end;
					else
						do;
							FileSpecification=cats(dinfo(pid, 'Directory'), '/', MemberName);
						end;
					%*** Ignore file locks.;

					if index(MemberName, '.lck')=0 then
						do;
							%*** Assign a file reference to the child directory.;
							rc3=filename(cref, FileSpecification);
							%*** 
							If the file assignment was successful then
								try and open the child directory.;
							%*** (NO)TE: File assignments are often successful in undesirable 
								situations.;

							if rc3=0 then
								do;
									cid=dopen(cref);
									%*** Store any system message i.e.;
									%*** (ER)ROR: Physical file does not exist, /.../.../...;
									%*** (ER)ROR: Insufficient authorization to access /.../.../...;
									SysMsg=sysmsg();
								end;
							else
								do;
									cid=.;
								end;
							%*** Clear the file assignment as we are now using the cid variable.;
							rc4=filename(cref);
							%*** Override errors for trying to open a member as a directory when it 
								is not a directory.;

							if substr(SysMsg, 1, 
								length('ERROR: A component of'))='ERROR: A component of' and 
								substr(SysMsg, length(SysMsg)-length('is not a directory.')+1, 
								length('is not a directory.'))='is not a directory.' then
									do;
									SysMsg='';
								end;
							%*** 
							If opening the child directory was successful then
								output.;

							if cid > 0 then
								do;
									%*** 
										-------------------------------------------------------------------;
									%*** OUTPUT BLOCK 3 - Successfully read child directory.;
									%*** 
										-------------------------------------------------------------------;
									OwnerName=dinfo(cid, 'Owner Name');
									GroupName=dinfo(cid, 'Group Name');
									AccessPermission=dinfo(cid, 'Access Permission');
									FileSize=.;
									LastModified=dinfo(cid, 'Last Modified');
									Readable='Y';
									output;
								end;
							%*** Else
								try and handle the object as a file.;
							else if upcase("%superq(format)")='L' then
								do;
									%*** Attempt to open the child member as a file.;
									fid=mopen(pid, MemberName, 'I');
									%*** Store any system message.;
									SysMsg=sysmsg();
									%*** 
									If the child member is a file and it opened successfully then
										do this.;

											if fid > 0 then
												do;
													%*** 
														-------------------------------------------------------------------;
													%*** OUTPUT BLOCK 4 - Successfully read child file.;
													%*** 
														-------------------------------------------------------------------;
													OwnerName=finfo(fid, 'Owner Name');
													GroupName=finfo(fid, 'Group Name');
													AccessPermission=finfo(fid, 'Access Permission');
													FileSize=input(finfo(fid, 'File Size (bytes)'), 32.);
													LastModified=finfo(fid, 'Last Modified');
													Readable='Y';
													output;
												end;
											else if substr(SysMsg, 1, 
												length('ERROR: File is in use'))='ERROR: File is in use' then
													do;
													%*** 
														-------------------------------------------------------------------;
													%*** OUTPUT BLOCK 5 - Child member is in use and cant be read.;
													%*** 
														-------------------------------------------------------------------;
													OwnerName='';
													GroupName='';
													AccessPermission='';
													FileSize=.;
													LastModified='';
													Readable='X';
													output;
												end;
											else
												do;
													%*** 
														-------------------------------------------------------------------;
													%*** OUTPUT BLOCK 6 - Child member has an error other than cant be 
														read.;
													%*** 
														-------------------------------------------------------------------;
													OwnerName='';
													GroupName='';
													AccessPermission='';
													FileSize=.;
													LastModified='';
													Readable='N';
													output;
												end;
										end;
									else
										do;
											%*** 
												-------------------------------------------------------------------;
											%*** OUTPUT BLOCK 7 - For short listing only.;
											%*** 
												-------------------------------------------------------------------;
											OwnerName='';
											GroupName='';
											AccessPermission='';
											FileSize=.;
											LastModified='';
											Readable='Y';
											output;
										end;
									%*** Close the child directory.;
									rc5=dclose(cid);
								end;
						end;
				end;
				%*** Close the parent directory.;
				rc6=dclose(pid);
			run;

			%*** Get the log back.;

			proc printto log=LOG;
			run;

			%*** Tidy up variables and define new ones where required.;

			data WORK._LS_CLEANSING_;
				set WORK._LS_LISTING_;
				length Type $1 OctalPermission 3 LastModifiedDate 8 LastModifiedTime 8;
				format LastModifiedDate date9.       LastModifiedTime time8.;
				%*** Define the type based on the first substring of the access 
					permissions.;

				if substr(AccessPermission, 1, 1) ^='-' then
					Type=substr(AccessPermission, 1, 1);
				else
					Type='f';
				%*** Define the octal representation of the access permissions.;
				OctalPermission=0;

				if AccessPermission ^='' then
					do;

						if substr(AccessPermission, 2, 1) ^='-' then
							OctalPermission=OctalPermission + 400;

						if substr(AccessPermission, 3, 1) ^='-' then
							OctalPermission=OctalPermission + 200;

						if substr(AccessPermission, 4, 1) ^='-' then
							OctalPermission=OctalPermission + 100;

						if substr(AccessPermission, 5, 1) ^='-' then
							OctalPermission=OctalPermission + 40;

						if substr(AccessPermission, 6, 1) ^='-' then
							OctalPermission=OctalPermission + 20;

						if substr(AccessPermission, 7, 1) ^='-' then
							OctalPermission=OctalPermission + 10;

						if substr(AccessPermission, 8, 1) ^='-' then
							OctalPermission=OctalPermission + 4;

						if substr(AccessPermission, 9, 1) ^='-' then
							OctalPermission=OctalPermission + 2;

						if substr(AccessPermission, 10, 1) ^='-' then
							OctalPermission=OctalPermission + 1;
					end;
				else
					do;
						OctalPermission=.;
					end;
				%*** 
				If there is a last modified value then
					define the last modified date and time.;

				if LastModified ^='' then
					do;
						LastModifiedDate=input(cats(scan(LastModified, 1, ' '), 
							substr(scan(LastModified, 2, ' '), 1, 3), scan(LastModified, 3, ' ')), 
							date9.);
						LastModifiedTime=input(scan(LastModified, 4, ' '), time8.);
					end;
			run;

			%*** Define which variables we will keep based on the long or short formats.;

			%if %sysfunc(upcase(%superq(format)))=L %then
				%do;
					%let keep = OwnerName, GroupName, Type, AccessPermission, OctalPermission, 
						FileSize, LastModifiedDate, LastModifiedTime;
				%end;
			%else
				%do;
					%let keep = Type;
				%end;
			%*** Re-order the columns and order as desired.;

			proc sql;
				create table %superq(out_ref) as select FileSpecification, case when 
					FileSpecification='/' then '' when count(FileSpecification, '/')=1 then 
					'/' else substr(FileSpecification, 1, length(FileSpecification) 
					- length(scan(FileSpecification, -1, '/'))-1) end as ParentDirectory 
					length=512
		, case when FileSpecification='/' then '' else scan(FileSpecification, -1, 
					'/') end as ShortFileName length=128
		, %superq(keep) , Readable
		, SysMsg from WORK._LS_CLEANSING_ order by FileSpecification;
			quit;

			%*** Delete the temp table(s).;

			proc datasets lib=work nolist;
				delete _LS_NEXT_ _LS_LISTING_ _LS_CLEANSING_;
				run;
			quit;

			%*** Remember the current value of options prior to changing them.;

			/*%options_reset(options=mlogic mprint notes symbolgen, options_id=sys_ls, put=N);*/
%mend sys_ls;

/*		%sys_ls(ls_path=/home/sukgeb);*/