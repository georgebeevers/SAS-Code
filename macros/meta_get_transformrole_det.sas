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
options nosymbolgen nomprint nomlogic;

/*options symbolgen mprint mlogic;*/
/*%put &omsid1;*/
/*Macro to read all job transformrole by step*/
%macro get_job_transformrole_det();
	/*Get a list of the jobs in metadata*/
	%meta_extractjobs(table=job_list);

	proc sql;
		create table uniq_jobs as
			select distinct ID
				,name as job_name 
			from job_list;

		/*			where name ="New Job 33150";*/
		/*			where name ="1_ACCESS_TRANSFORMATIONS" or name ="New Job 33150";*/
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
/*Filter out only the steps and then obtain the associations from the steps*/
/*This will bring in the class object where the full TransformRole can be obtained from. Truncations occurs on the */
/*TransformRole*/
		proc sql;
			create table WORK._JOB_STEPS as 
				select assoc_uri as jobactivities_uri
					from WORK._JOBACTIVITIES_ASSOC&k.
						where assoc='Steps'
			;
		quit;

		%metadata_transassoc(omsobj=work._JOB_STEPS, uri=jobactivities_uri, out_ref=WORK._JOBPROPS&k.);

		/*Detect zero obs and then move on to the next loop without inserting. This occurs when a transform does not*/
		/*have a class associated with the object*/
		%let dsid=%sysfunc(open(work._JOBPROPS&k.));
		%let nobs=%sysfunc(attrn(&dsid,nlobs));
		%let vnum = %sysfunc(varnum(&dsid,ID));
		%let dsid=%sysfunc(close(&dsid));

		%if &nobs = 0 /*or &vnum =0*/
		%then

			%do;
				%goto exit_no_obs;
			%end;

		proc sql;
			create table stop_truncation as
				select
					"&&omsid&k." as OMSOBJ_SEARCHID length=20
					,"&&job_name&k." as JOB_NAME length=150
					,a.uri length=150
					,a.assoc_uri length=100
					,a.ID length=50
					,b.name as USER_DEFINED_NAME length=50
					,
				case 
					when a.defaultvalue contains "-" then " " 
					else a.defaultvalue 
				end 
			as TRANSFORMROLE_CLASS length=100
				,b.transformrole as TRANSFORMROLE_STEP length=100
				,b.desc as USER_DEFINED_DESC length=300
			from _JOBPROPS&k. as a
				left join
					_JOBACTIVITIES_ASSOC&k. as b
					on a.uri =b.assoc_uri
				where a.assoc="Properties" and propertyname ="Class";
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

%exit_no_obs:

		proc datasets lib=work noprint;
			delete _job:;
		run;

	%end;

	proc datasets lib=work noprint;
		delete stop_truncation;
		delete uniq_jobs;
	run;

%mend;

/*%get_job_transformrole_det();*/

