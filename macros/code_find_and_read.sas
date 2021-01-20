/*************************************************************************************************************/
/*  PROGRAM NAME: CODE_PARSER.SAS  		   	 	                                    						 */
/*  DATE CREATED: 23/01/2020                                                      							 */
/*  AUTHOR: GEORGE BEEVERS						                                                			 */
/*  PURPOSE: FIND SAS CODE AND THEN PARSE FOR KEY WOORD													     */
/*  INPUTS:								  |              					                        		 */
/*		TBD																									 */
/*  OUTPUTS:                                                                       							 */
/*  	TBD																									 */
/* --------------------------------------------------------------------------------------------------------- */
/*  Macros: FIND_FILES	                                                         							 */
/*                                                                                 							 */
/* --------------------------------------------------------------------------------------------------------- */
/*===========================================================================================================*/
/* PIPE IN WINDOWS FILELISTING OF .SAS				                          								 */
/*===========================================================================================================*/
/*-----------------------------------------------------------------------------------------------------------*/
/* FIND ALL SAS CODE AND CREATE A DIRECTORY LISTING. THIS LIST WILL BE PASSED TO THE FIND_FILES MACRO		 */
/*-----------------------------------------------------------------------------------------------------------*/
options fullstimer;
/*options symbolgen mprint mlogic;*/

/*-----------------------------------------------------------------------------------------------------------*/
/* READ IN CONTENTS OF ALL SAS FILES IDENTIFIED EARLIER. EVERY LINE OF CODE WILL BE HELD IN ONE LARGE TABLE	 */
/*-----------------------------------------------------------------------------------------------------------*/
%macro find_files(search_path=);
/*===========================================================================================================*/
/* FIND_FILES MACRO									                          								 */
/*===========================================================================================================*/

Filename filelist pipe %str("dir /b /s &search_path.\*.sas");	

	Data directory;
		Infile filelist truncover lrecl=25000;
		Input filename $400.;
		Put filename=;
	Run;

	data keep (drop= pos length filename);
		set directory;
		call scan(filename,-1,pos, length,"\");
		dir_path= substr(filename,1,pos-1);
	run;

	/*Remove any duplicates*/
	proc sort data = keep nodupkey;
		by dir_path;
	run;

	proc sql;
		select count(*) into:iter_count trimmed
			from keep;
	quit;

	proc sql;
		select dir_path into: path1 - :path&iter_count.
			from keep;
	quit;

/*	%put &path113.;*/
	%put &iter_Count;

	%do i=1 %to &iter_count.;
		%let dir=&&path&i.;

		/*		%put %&path&i.;*/
		data files&i. (keep=filename full_path label="All SAS programs in a directory");
			length filename full_path $1250;
			rc=filename("dir","&dir");
			did=dopen("dir");

			if did ne 0 then
				do;
					do i=1 to dnum(did);
						filename=dread(did,i);
						full_path="&dir"||filename;

						if lowcase(scan(filename, -1, "."))="sas" then
							output;
					end;
				end;
			else
				do;
					put "ERROR: Failed to open the directory &dir";
					stop;
				end;
		run;

	%end;

	data file_full;
		set files:;
	run;

	proc sort data = file_full nodupkey out=dups;
		by filename;
	run;

	proc sort data=file_full;
		by full_path;
	run;

	data contents (label="Original files' full contents"
		rename=(full_path_tmp=full_path));
		set file_full end=last;
		length full_line $2000;
		infile codes filevar=full_path truncover lrecl=32767
			length=line_length_tmp end=all;
		full_path_tmp=full_path;
		line_number=0;

		do while(not all);
			input;
			full_line=compress(_infile_, '09'x);/*Remove tab delimiter from file. Held as a hidden char and affects later procedures*/
			line_length=line_length_tmp; /*get the lenght of the line minus the missing / blanks*/
			line_number+1; /*line number in the file. Used when lines have been identified as highlights area*/
			word_Count=countw(full_line, " ''\=/"); /*count the number of words on a line. Can be summed for total count. Long UNIX paths will be treated as 1 but good for an approximation*/
			output;
		end;
	run;
proc datasets lib=work noprint;
delete FILES:;
delete directory;
delete dups;
delete file_full;
delete keep;
run;
%mend;



/*===========================================================================================================*/
/* END OF FIND_FILES MACRO									                          						 */
/*===========================================================================================================*/
