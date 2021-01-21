/*************************************************************************************************************/
/*  PROGRAM NAME: META_GET_PRE_POST_CODE     	                                    						 */
/*  DATE CREATED: 15/12/2020                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION: EXTRACT ALL PRE AND POST CODE IN DIS JOBS													 */
/*  																										 */
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
/*Testing options*/
/*options symbolgen mlogic mprint;*/
%macro get_pre_post_code(trantype=, table=);
	%meta_extractjobs(table=job_list);

	proc sql;
		create table uniq_jobs as
			select distinct ID
				,name as job_name 
			from job_list;

		/*where id="A5VMVDCA.BP000A30";*/
	quit;

	/*Delete job_list as not needed now*/
	proc datasets lib=work noprint;
		delete job_list;
	run;

	proc sql;
		select ID, job_name into: omsid1 - ,:job_name1 -
			from uniq_jobs;

		/*where ID="A5VMVDCA.BP0000RU";*/
	quit;
/*Check that Transformation Sources or Targets has been specified. If they have then the loop is allowed */
/*to start. If the incorrect information has been passed then the macro exits.*/
	%if "&trantype." ="TransformationSources" %then
		%do;
			%let label=PRECODE;
			%goto start_loop;
		%end;

	%if "&trantype." ="TransformationTargets" %then
		%do;
			%let label=POSTCODE;
			%goto start_loop;
		%end;
	%else
		%do;
			%goto exit_no_transformation;
		%end;

%start_loop:

	/*Check for the existance of the dataset and delete if present*/
	%if %sysfunc(exist("&label."))=0 %then
		%do;

			proc datasets lib=work;
				delete &label.;
			run;

		%end;

	%do a=1 %to %get_obscnt(uniq_jobs);
		%metadata_transassoc(omsobj=OMSOBJ:JOB\&&omsid&a., out_ref=WORK._JOB_TOP_LEVEL_ASSOC);

		proc sql;
			create table WORK._JOBACTIVITIES as 
				select assoc_uri as jobactivities_uri
					from WORK._JOB_TOP_LEVEL_ASSOC
						where assoc="&trantype."
			;
		quit;

		%metadata_transassoc(omsobj=work._jobactivities, uri=jobactivities_uri, out_ref=WORK._JOBACTIVITIES_ASSOC&a.);

		/*proc sql;*/
		/*		create table preprocess_code as*/
		/*			select * from _JOBACTIVITIES_ASSOC&a.*/
		/*				where assoc ="SourceCode";*/
		/*	quit;*/
		/*No observations will be found when precode is not present. In these cases we dont want to create or insert*/
		/*into the main table. It will create a warning and error due to the variables not matching. When observations*/
		/*are 0 the create and insert steps are skipped using %goto exit_no_obs*/
		/*Additional check made on the storedtext variable. When the variable does not exist the process will goto exit_now*/
		%let dsid=%sysfunc(open(work._jobactivities_assoc&a.));
		%let nobs=%sysfunc(attrn(&dsid,nlobs));
		%let vnum = %sysfunc(varnum(&dsid,storedtext));
		%let dsid=%sysfunc(close(&dsid));

		%if &nobs = 0 or &vnum =0 %then
			%do;
				%goto exit_no_obs;
			%end;

		proc sql;
			create table keep_data as
				select
					"&&omsid&a." as OMSOBJ_SEARCHID length=20
					,"&&job_name&a." as JOB_NAME length=150
					,"&label." as type
					,assoc
					,name length=30
					,storedtext length=32767
				from _JOBACTIVITIES_ASSOC&a.;
		quit;

		%if %sysfunc(exist(&table.)) %then
			%do;
				/*Create DataSet Info Table*/
				proc sql;
					insert into &table.
						select * from keep_data
							where assoc ="SourceCode";
				quit;

			%end;
		%else
			%do;

				data &table.;
					set keep_data;
					where assoc ="SourceCode";
				run;

			%end;

		proc datasets lib=work noprint;
			delete _job:;
		run;

%exit_no_obs:

		/*Remove those which used the exit_no_obs gate*/
		proc datasets lib=work noprint;
			delete _job:;
		run;

	%end;

	/*Remove keep_data*/
	proc datasets lib=work noprint;
		delete keep_data;
	run;

	/*%end;*/
	/*Exit as no transformation specified*/
%exit_no_transformation:
%put Exiting Loop due to missing information;
%put Please specify TransformationSources or TransformationTargets as the trantype;

proc datasets lib=work;
	delete uniq_jobs;
run;
%mend;

/*%get_pre_post_code(trantype=Transformations);*/
/*%get_pre_post_code();*/
/*%get_pre_post_code(trantype=TransformationSources);*/
/*%get_pre_post_code(trantype=TransformationTargets);*/

/*%get_pre_post_code(trantype=TransformationSources,label=PRECODE,tablename=preprocess_code);*/
/*%get_pre_post_code(trantype=TransformationTargets,label=POSTCODE,tablename=postprocess_code);*/