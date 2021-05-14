/**************************************************************************************************************/
/*  PROGRAM NAME: GET_UNIX_FILELIST.SAS     	                                    						  */
/*  DATE CREATED: 28/04/2021                                                      							  */
/*  AUTHOR: GEORGE BEEVERS						                                                 			  */
/*  PURPOSE: THE CODE IS DESIGNED TO CREATE A FULL FILE LISTING FROM A UNIX OR OR LINUX FILESYSTEM. IT WILL   */
/*  FIRST LIST ALL FILES USING AN LS COMMAND. TO THEN GET THE MODIFIED DATA THE PROCESS IS REPEATED WITH A    */
/*  LS -LU COMMAND   																						  */
/*  INPUTS:								  |              					                        		  */
/*		SAS_FILES.TXT																						  */
/*		SAS_FILES_LSLU.TXT																					  */
/*  OUTPUTS:                                                                       							  */
/*  	WORK.FILE_LIST_UNIX_BASE																			  */
/*		WORK.FILE_LIST_UNIX_LSLU																		 	  */
/* ---------------------------------------------------------------------------------------------------------- */
/*  VERSION CONTROL		                                                         							  */
/*  1.0 28/04/2021 INTIAL VERSION  GBEEVERS                                        							  */
/* ---------------------------------------------------------------------------------------------------------- */
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
/* 1. PATH = The area for the find command to be executed on when using SHELL_ESCAPE = Y 					  */
/* This parameter is also used to scan and split the full path into sub directories so it must be set on all  */
/* occassion. Format = /sas/prod/uk/{department}															  */
/* 2. LOCAL_PATH = Windows / UNIX or LINUX location of the file. Used when SSH Pipes not being used			  */
/* 3. OUTPUT = Default name set ot FILE_LIST_UNIX_&TBLEXT when omitted. Can be changed by setting the 		  */
/* parameter.																								  */
/* 4. ATIME = Set to Y when reading in a file from the LS -LU procedure. The data structure is slightly		  */
/* different and this allows the data to be read in correctly. It also sets the TBLEXT to LSLU or BASE to     */
/* highlight what type of file has been read																  */
/* 5. SERIES = Default set to 1 and then incremented up to allow more than one file to be read by the process */
/* If the series is not changed then results can be overwritten. If working with one file then omit and leave */
/* as the default.																							  */
/* 6. SHELL_ESCAPE = Set to Y if shell escape (XCMD) is available and you wish to pipe the results in. 		  */
/* When set to Y LOCAL_PATH is not needed																	  */
/*------------------------------------------------------------------------------------------------------------*/

/*TESTING ONLY OPTIONS*/
/*options symbolgen mprint mlogic;*/
%macro unix_file_list(path,filepath=,output=FILE_LIST_UNIX,atime=N,series=1,shell_escape=N);
/*============================================================================================================*/
/* TABLE EXTENSION						                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Set the table extension depending on the command being executed. If ATIME=Y then a LS -LU command is being */
/* run. In this case the extension of tablename_&tblext will reflect. No ATIME will be BASE					  */
/*------------------------------------------------------------------------------------------------------------*/
%if &ATIME=Y %then
	%do;
		%let tblext=LSLU;
		%put Note: Using Table Extension of &TBLEXT.;
	%end;
%if &ATIME=N %then
	%do;
		%let tblext=BASE;
		%put Note: Using Table Extension of &TBLEXT.;
	%end;

/*============================================================================================================*/
/* BASE TABLE DELETION					                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* If the original table exists and this is the first run then the table is removed. Any other run of the code*/
/* would append data to the base table																		  */
/*------------------------------------------------------------------------------------------------------------*/
%if &series=1 and %sysfunc(exist(&output._&tblext.)) %then %do;
  proc delete data=&output._&tblext.; run;
%end;
/*============================================================================================================*/
/* SHELL ESCAPE	(UNIX/LINUX)			                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* If shell escape has been set to Y then the input is piped direclty in the process. An addiitonal flag 	  */
/* exists for ATIME and directs the query to either perform a standard listing or one with the files last 	  */
/* accesssed timestamp																						  */
/*------------------------------------------------------------------------------------------------------------*/
%if (&shell_escape = Y and &ATIME=N) %then %do;
	%put NOTE: Shell escaping starting for standard file listing;
  filename x pipe "find ""&path."" -type f -ls 2>/dev/null" lrecl=32767;
%end;
%if (&shell_escape = Y and &ATIME=Y) %then %do;
%put NOTE: Shell escaping starting for ATIME listing;
  filename x pipe "find ""&path."" -type f -exec ls -lu {} 2>/dev/null" lrecl=32767;
%end;
/*============================================================================================================*/
/* COUNTER								                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Set the counter to zero to start the extract. If data is returned then its set to 1. If it remains at 0    */
/* no data has been found in the file. Check the filepath before resubmitting								  */
/*------------------------------------------------------------------------------------------------------------*/
%let _total_=0;
	data files_&series.;
/*------------------------------------------------------------------------------------------------------------*/
/* Set the length, format and label of the required variables												  */
/*------------------------------------------------------------------------------------------------------------*/
	attrib  D_START  length=4. format=date9. label='Load Date'
			FILENAME  length=$1024  label='Filename'
			DIRECTORY length=$1024  label='Directory'
			GRID_SUB_DIRECTORY length=$1024  label='Grid Sub Directory'
			GRID_SUB_FILENAME length=$1024  label='Grid Sub File Name'
			SHORT_FILENAME  length=$1024  label='User ID'
			EXTENSION  length=$64  label='File Extension'
			GROUP  length=$64  label='Owning Group'
			PERMISSIONS  length=$64  label='Permissions'
			USERNAME  length=$64  label='User Name'
			SIZE_BYTES  length=4.  label='File Size in Bytes'
			SIZE_KB  length=4.  label='File Size in KB'
			SIZE_MB  length=4.  label='File Size in MB'
			SIZE_GB  length=4.  label='File Size in GB'
			DTTM_MODIFIED  length=4. format=datetime20. label='Date Last Modified';
/*------------------------------------------------------------------------------------------------------------*/
/* TEMPORARY LENGTHS                                                   								  	  	  */
/* Assign to avoid 32767 being assigned as the default. Variables are dropped aafter processing			      */
/*------------------------------------------------------------------------------------------------------------*/
length SIZEC month day colon $50.;
/*============================================================================================================*/
/* SHELL ESCAPE INFILE					                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Conditional flags to either read from the piped input ot a flat file proviced on the filepath= variable    */
/*------------------------------------------------------------------------------------------------------------*/
%if &shell_escape=Y  %then %do;
		infile x dlm= " ";
%end;
%if &shell_escape ne Y %then %do;
		infile "&filepath." dlm= " ";
%end;
		input;
/*============================================================================================================*/
/* ATIME (YES/NO)						                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Postionally the data is different due to the different commands executed. To cater for this the conditional*/
/* logic allows two different reads to occur. ATIME=YES/NO													  */
/*------------------------------------------------------------------------------------------------------------*/
		%if &atime.=N %then
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

		%if &atime.=Y %then
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
/*		format D_START date9. DTTM_MODIFIED datetime20.;*/
		drop COLON DAY DT_MODIFIED MONTH SIZEC POS LEN;

		if _n_=1 then call symput ("_total_","1");
	run;

%if &_total_=0 %then %put &path has returned 0 items;
/*============================================================================================================*/
/* APPEND DATA							                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Append any of the series to the main table. If the series is set to 1 then the base file is removed	 	  */
/*------------------------------------------------------------------------------------------------------------*/
proc append base=&output._&tblext. data=work.files_&series;
run;
/*============================================================================================================*/
/* CLEAN UP								                                    								  */
/*============================================================================================================*/
/*------------------------------------------------------------------------------------------------------------*/
/* DESCRIPTION                                                   								  	  		  */
/* Remove any remporary files																			 	  */
/*------------------------------------------------------------------------------------------------------------*/
proc datasets lib=work nolist;
delete files_&series;
run;
%mend unix_file_list;




/*%unix_file_list(/anenv/prd/cads/cads1/,filepath=C:\temp\file_listing\sas_files_cads1_290121.txt,shell_escape=Y);*/
/*%unix_file_list(/anenv/prd/cads/cads1/,filepath=C:\temp\file_listing\sas_files_cads1_290121.txt,atime=Y,series=2,shell_escape=Y);*/