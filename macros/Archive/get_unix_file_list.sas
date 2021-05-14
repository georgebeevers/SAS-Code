/*TESTING ONLY OPTIONS*/
/*options symbolgen mprint mlogic;*/
/*************************************************************************************************************/
/*  PROGRAM NAME: CREATE_SAS_FILELIST.SAS      	                                    						 */
/*  DATE CREATED: 17/01/2020                                                      							 */
/*  AUTHOR: AMIT PATEL AND GEORGE BEEVERS(ADAPTED)                                                 			 */
/*  PURPOSE: THE CODE IS DESIGNED TO CREATE A FULL FILE LISTING FROM A UNIX OR OR LINUX FILESYSTEM. IT WILL  */
/*  FIRST LIST ALL FILES USING AN LS COMMAND. TO THEN GET THE MODIFIED DATA THE PROCESS IS REPEATED WITH A   */
/*  LS -LU COMMAND   																						 */
/*  INPUTS:								  |              					                        		 */
/*		SAS_FILES.TXT																						 */
/*		SAS_FILES_LSLU.TXT																					 */
/*  OUTPUTS:                                                                       							 */
/*  	WORK.FILE_LIST_UNIX_BASE																			 */
/*		WORK.FILE_LIST_UNIX_LSLU																			 */
/*		WORK.UNIX_FILE_LIST_FULL																			 */
/* --------------------------------------------------------------------------------------------------------- */
/*  Macros: UNIX_FILE_LIST                                                         							 */
/*                                                                                 							 */
/* --------------------------------------------------------------------------------------------------------- */
/*------------------------------------------------------------------------------------------------------------*/
/* BASIC COMMAND EXAMPLES                                                   								  */
/* 1. FULL FILE LISTING																					   	  */
/* find /sas/prod/.../mypath/ -type f -ls 2>/dev/null >/sas/prod/.../location/{Filename}.txt 				  */
/* EXAMPLE = find /mnt/c/Users/sukgeb/tmp -type f -ls 2>/dev/null >sas_files.txt 							  */
/*																											  */
/* 2. AGED FILES - ATIME																					  */
/* find /sas/prod/.../mypath/ -type f  -exec ls -lu {} \; 2>/dev/null >/sas/prod/.../location/{Filename}.txt  */
/* EXAMPLE = find /mnt/c/Users/sukgeb/tmp -type f  -exec ls -lu {} \; 2>/dev/null >sas_files_lslu.txt		  */
/*------------------------------------------------------------------------------------------------------------*/
/*============================================================================================================*/
/* MACRO START: READ IN UNIX FILE LISTING                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* MACRO PARAMETERS                                                        								      */
/* 1. LOCAL_PATH = Windows / UNIX or LINUX location of the file. Used when SSH Pipes not being used  		  */
/* 2. PATH = Mount point short name /sas/prod/uk/{department}										   		  */
/* 3. OUTPUT = Output dataset name.											 								  */
/* 4. ATIME = Set to yes when using LSLU command in the file.	  				 							  */
/*------------------------------------------------------------------------------------------------------------*/

/*############################################################################################################*/
/*PIPING UNIX / LINUX COMMAND*/
/*If piping in the command the script will need to be amended with the following before the query executes.*/
/*%if &ssh ne ssh %then %do;*/
/*  filename x pipe "find ""&path."" -name ""&file."" &options &type. -ls 2>/dev/null" lrecl=32767;*/
/*%end;*/
/**/
/*Amend infile statement to:*/
/*infile x dlm=" ";*/
/**/
/*Ensure that the options are change for ATIME and that the %if &atime.=NO includes %if &ssh ne ssh.*/
/**/
/*Note - dont forget to expand out the parameters of the macro */
/*############################################################################################################*/

%macro unix_file_list(local_path=,path=,output=,atime=);

	data &output.;
		length D_START 4 FILENAME DIRECTORY GRID_SUB_DIRECTORY GRID_SUB_FILENAME SHORT_FILENAME $1024 EXTENSION GROUP PERMISSIONS USERNAME $64;;
		label SIZE_BYTES = "File Size in Bytes"
			SIZE_KB = "File Size in KB"
			SIZE_MB = "File Size in MB"
			SIZE_GB = "File Size in GB"
			DTTM_MODIFIED= "Date Last Modified"
			PERMISSIONS = "Permissions";

		infile "&local_path." dlm= " ";

		input;

		%if &atime.=NO %then
			%do;
				PERMISSIONS=scan(_infile_,3," ");
				USERNAME=scan(_infile_,5," ");
				GROUP=scan(_infile_,6," ");
				SIZEC=scan(_infile_,7," ");
				MONTH=scan(_infile_,8," ");
				DAY=scan(_infile_,9," ");
				COLON=scan(_infile_,10," ");
				call scan(_infile_,11,POS,LEN," ");
			%end;

		%if &atime.=YES %then
			%do;
				PERMISSIONS=scan(_infile_,1," ");
				USERNAME=scan(_infile_,3," ");
				GROUP=scan(_infile_,4," ");
				SIZEC=scan(_infile_,5," ");
				MONTH=scan(_infile_,6," ");
				DAY=scan(_infile_,7," ");
				COLON=scan(_infile_,8," ");
				call scan(_infile_,9,POS,LEN," ");
			%end;

		FILENAME = strip(substr(tranwrd(_infile_,"\ "," "),POS));
		call scan(FILENAME,-1,POS,LEN,"/");
		DIRECTORY = strip(substr(FILENAME,1, max(1,POS-2)));
		SHORT_FILENAME = strip(substr(FILENAME, POS));

		if index(SHORT_FILENAME,".") >0 then
			EXTENSION = strip(scan(SHORT_FILENAME,-1,"."));
		GRID_SUB_DIRECTORY = strip(tranwrd(DIRECTORY, "&path.", ""));
		GRID_SUB_FILENAME = strip(tranwrd(FILENAME, "&path.", ""));
		D_START=today();

		if index(COLON,':') then
			do;
				DT_MODIFIED = input(trim(day)||trim(month)||put(year(today()),4.),date9.);

				if DT_MODIFIED > today() then
					DTTM_MODIFIED = input(cats(put(intnx('YEAR',DT_MODIFIED,-1,'S'),date9.),":",COLON,":00"),datetime.);
				else DTTM_MODIFIED = input(cats(put(DT_MODIFIED,date9.),":",COLON,":00"),datetime.);
			end;
		else DTTM_MODIFIED = input(cats(DAY,MONTH,COLON,":00:00:00"),datetime.);
		SIZE_BYTES=input(SIZEC,16.);
		SIZE_KB=input(SIZEC,16.)/1024;
		SIZE_MB=input(SIZEC,16.)/(1048576);
		SIZE_GB=input(SIZEC,16.)/(1073741824);
		format D_START date9. DTTM_MODIFIED datetime20.;
		drop COLON DAY DT_MODIFIED MONTH SIZEC POS LEN;

		if _n_=1 then
			call symput ("_total_","1");
	run;

	/*Load in many files to create one file for the day*/
/*	proc append base=&output. data=WORK.FILES_&series;*/
/*	run;*/
/*Remove the temporary file*/
proc datasets lib=work;
delete files_1;
run;
%mend unix_file_list;

