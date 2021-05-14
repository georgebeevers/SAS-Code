/*************************************************************************************************************/
/*  PROGRAM NAME: META_GET_JOB_SOURCECODE      	                                    						 */
/*  DATE CREATED: 15/12/2020                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION: EXTRACT ALL USER WRITTEN CODE NODES FROM JOBS												 */
/*  CODE CAN BE EXPORTED TO A LAN OR SERVER LOCATION IF NEEDED												 */
/*  				   																						 */
/*  MACROS:								  |              					                        		 */
/*  %meta_extractjobs.sas																					 */
/*  %metadata_transassoc.sas																				 */
/*  %metadata_transattr.sas																					 */
/*  %get_obscnt.sas																							 */
/* --------------------------------------------------------------------------------------------------------- */
/*  VERSION CONTROL		                                                         							 */
/*  V1.0 15/12/2020 INITIAL VERSION GEORGE BEEVERS                                 							 */
/* --------------------------------------------------------------------------------------------------------- */
/*Get a list of the jobs in metadata*/
/*Testing Options*/


%macro meta_get_user_code(path=,table=);
proc datasets lib=work noprint;
	delete SASUserExit;
	delete &table.;
run;
	/*Get a list of jobs*/
	%meta_extractjobs(table=job_list);

	proc sql;
		create table uniq_jobs as
			select distinct ID
				,name as job_name 
			from job_list;

		/*where id="A5VMVDCA.BP000A30";*/
	quit;

	/*Delete job_list as not needed now*/
	proc datasets lib=work;
		delete job_list;
	run;

	proc sql noprint;
		select ID, job_name into: omsid1 - ,:job_name1 -
			from uniq_jobs;

		/*where id="A5VMVDCA.BP0000RU";*/
	quit;

	%do c=1 %to 2/*%get_obscnt(uniq_jobs)*/;
		%metadata_transassoc(omsobj=OMSOBJ:JOB\&&omsid&c., out_ref=WORK._JOB_TOP_LEVEL_ASSOC);

		/*** Filter to keep just the jobactivities (there should only be one per Job unless the metadata is dodgy ***/
		proc sql;
			create table WORK._JOBACTIVITIES as 
				select assoc_uri as jobactivities_uri
					from WORK._JOB_TOP_LEVEL_ASSOC
						where assoc='JobActivities'
			;
		quit;

		/*** Get all associations of the jobactivities ***/
		%metadata_transassoc(omsobj=work._jobactivities, uri=jobactivities_uri, out_ref=WORK._JOBACTIVITIES_ASSOC&c.);

		/*Create a table of jobs with SASUserExit*/
		proc sql;
			create table insert_prep as
				select
					"&&omsid&c." as OMSOBJ_SEARCHID length=20
					,"&&job_name&c." as JOB_NAME length=150
					,transformrole	Length=	20			
					,uri	Length=	64			
					,assoc	Length=	32			
					,assoc_uri	Length=	64			
				from _JOBACTIVITIES_ASSOC&c.
					where transformrole ="SASUserExit";
		quit;

		%if %sysfunc(exist(SASUserExit)) %then
			%do;
				/*Create DataSet Info Table*/
				proc sql;
					insert into SASUserExit
						select * from insert_prep;
				quit;

			%end;
		%else
			%do;

				data SASUserExit;
					set insert_prep;
				run;

			%end;

		proc datasets lib=work;
			delete _job:;
		run;

	%end;

	/*Second Loop to get the code*/
	/*	proc sql;*/
	/*		create table SASUserExit as*/
	/*			select * from _JOBACTIVITIES_ASSOC&c.*/
	/*				where transformrole ="SASUserExit";*/
	/*	quit;*/
	/*Create macro variables of the key variables*/
	proc sql;
		select assoc_uri, job_name into:assoc_uri1 - ,:job_name1 -
			from SASUserExit
				where transformrole = "SASUserExit";
	quit;

	%do t=1 %to %get_obscnt(SASUserExit);
		%metadata_transassoc(omsobj=&&assoc_uri&t., out_ref=WORK._temp);

		proc sql;
			create table WORK._JOBTRANS as 
				select assoc_uri as jobtrans_uri
					from WORK._temp
						where assoc='Transformations';
		quit;

		%metadata_transassoc(omsobj=work._jobtrans, uri=jobtrans_uri, out_ref=WORK._JOBTRANS_ASSOC);

		/*Extract all of the objects with SourceCode assigned*/
		proc sql;
			create table _code_extract as
				select
					"&&job_name&t." as Job length=200
					,cat("&&job_name&t.","_",ID) as JOBID
					,uri
					,assoc
					,assoc_uri
					,ID
					,name length=20
					,storedtext length=32767
					,textrole
					,texttype
				from _jobtrans_assoc 
					where assoc="SourceCode";
		quit;

		/*Create one table for all code*/
		/*A check is made to see if table exists. if it does then the information is inserted. If not*/
		/*a new table is made. If placed in a batch cycle the base table could be held as an SCD2 and then */
		/*only the new entries are inserted. */
		%if %sysfunc(exist(&table.)) %then
			%do;
				/*Create DataSet Info Table*/
				proc sql;
					insert into &table.
						select * from _code_extract;
				quit;

			%end;
		%else
			%do;

				data &table.;
					set _code_extract;
				run;

			%end;

		/**/
		proc datasets lib=work noprint;
			delete _:;
		run;

		/*	%end;*/
	%end;

	/*	Add conditional logic to skip the code being exported to a LAN or server logcation*/
	/*If you want to export as code then the path= parameter needs to be set on the macro*/
	%if &path eq %then
		%do;
			%put Path Parameter is missing;
			%put If the code needs to be exported then enter a path location;
			%put Windows or Linux location depending on connnectivity;
			%goto exit_now;
		%end;

	%put NOTE: Path Parameter is OK (&Path.);

	/*Export as code to review*/
	proc sql;
		select jobid,uri,assoc_uri, id, job
			into: jobid1 - 
			,:uri1 -
			,:assoc_uri1 -
			,:id1 -
			,:job1 -
		from &table.;
	quit;

	/*Loop over the objects and export as code. A header has been added to each piece of code to */
	/*show where it came from. The URI and ID are unique to the object. Changes can be made to the header.*/
	/*If it also possible to write to metadata and change what is held in the object. See SAS Support for */
	/*more details*/
	%do p=1 %to %get_obscnt(&table.);
		filename xl "&path.\&&jobid&p...sas";

		data _null_;
			set &table. end=eof;
			where JOBID ="&&jobid&p.";

			/* using member syntax here */
			file   xl /*lrecl=256 recfm=N flowover*/;
			put "/*==============================================================*/";
			put "/*JOB = &&JOB&p.*/";
			put "/*URI = &&uri&p.*/";
			put "/*ASSOC_URI = &&assoc_uri&p.*/";
			put "/*ID = &&id&p.*/";
			put "/*CODE EXPORT DTTM: %sysfunc(datetime(),datetime.)*/";
			put "/*==============================================================*/";
			put StoredText;

			/*	return;*/
			/*eof:*/
			/*	stop;*/
		run;

	%end;

%exit_now:
	%exit_loop:
	/*	Tidy Up*/
	proc datasets lib=work;
		delete SASUserExit;
		delete insert_prep;
		delete uniq_jobs
			run;
%mend;
%meta_get_user_code(table=user_Code);

/*%meta_get_user_code;*/
/*%meta_get_user_code(path=C:\temp\LSF\Code\meta_sourcecode);*/