/*************************************************************************************************************/
/*  PROGRAM NAME: META_GET_JOB_TRANSFORMROLE   	                                    						 */
/*  DATE CREATED: 15/12/2020                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION: EXTRACT ALL TRANSFORMROLES USED. THIS CAN THEN BE USED TO SEE WHAT TRANSFORMS ARE BEING USED*/
/*  TRANFORMS CHOSEN IN DIS ARE MAPPED TO CERTAIN TYPES AND COMMON USAGE CAN BE DETERMINED.					 */
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

/*%put &omsid1;*/
/*Macro to read all job transformrole by step*/
%macro get_job_transformrole();
	/*Get a list of the jobs in metadata*/
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
	quit;

	/*Delete the final table - used during testing*/
	proc datasets lib=work;
		delete job_Transformrole;
	run;

	%do k=1 %to %get_obscnt(uniq_jobs);

		/*** Get all associations of a job ***/
		%metadata_transassoc(omsobj=OMSOBJ:JOB\&&omsid&k., out_ref=WORK._JOB_TOP_LEVEL_ASSOC);

		/*** Filter to keep just the jobactivities (there should only be one per Job unless the metadata is dodgy ***/
		proc sql;
			create table WORK._JOBACTIVITIES as 
				select assoc_uri as jobactivities_uri
					from WORK._JOB_TOP_LEVEL_ASSOC
						where assoc='JobActivities'
			;
		quit;

		/*** Get all associations of the jobactivities ***/
		%metadata_transassoc(omsobj=work._jobactivities, uri=jobactivities_uri, out_ref=WORK._JOBACTIVITIES_ASSOC&k.);

		proc sql;
			create table stop_truncation as
				select
					"&&omsid&k." as OMSOBJ_SEARCHID length=20
					,"&&job_name&k." as JOB_NAME length=150
					,desc	Length=200			
					,name	Length=100			
					,transformrole	Length=	20			
					,uri	Length=	64			
					,assoc	Length=	32			
					,assoc_uri	Length=	64			
					,ChangeState	Length=	1			
					,Id	Length=	17			
					,MetadataCreated	Length=	18			
					,MetadataUpdated	Length=	18			
					,PublicType	Length=	5			
					,UsageVersion	Length=	7			
				from _JOBACTIVITIES_ASSOC&k.;
		quit;

		%if %sysfunc(exist(job_transformrole)) %then
			%do;
				/*Create DataSet Info Table*/
				proc sql;
					insert into job_transformrole
						select * from stop_truncation;
				quit;

			%end;
		%else
			%do;

				data job_transformrole;
					set stop_truncation;
				run;

			%end;

		proc datasets lib=work noprint;
			delete _job:;
		run;

	%end;

	proc datasets lib=work noprint;
		delete stop_truncation;
		delete uniq_jobs;
	run;

%mend;

