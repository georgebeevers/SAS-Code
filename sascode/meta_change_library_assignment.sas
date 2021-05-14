/*Change Metadata Library Assignment*/
/*Toggle 0 and 1 to make them preassigned or not. */
%meta_extractlibraries();




/*Obtain preassigned libraries and create macro var*/
/*STPSAMP and SASDATA are excluded as these are preassigned as default in my setup and it*/
/*saves me forgetting to set thema back after testing*/
proc sql;
	select ID, count(*) as obs into: URI1 - ,: numobs 
		from libraries 
			where IsPreassigned ="1" /*and libref = "ODD";*/
				and libref not in ("stpsamp","SASDATA");
quit;

/*%put &numobs;*/
/*STP Samples	BASE	0	1	A5VMVDCA.B4000002*/
/*SASApp - SASDATA	BASE	0	1	A5VMVDCA.B4000001*/
/*omsobj:SASLibrary/A5VMVDCA.B40000RU*/
%macro change_preassignment();
	%do k=1 %to &numobs.;
		%metadata_transassoc(omsobj=omsobj:SASLibrary/&&URI&k.,out_ref=work.dir_top_level_assoc);

		proc sql;
			create table WORK.JOBACTIVITIES as 
				select assoc_uri as jobactivities_uri
					from WORK.dir_top_level_assoc
						where assoc='UsingPackages';
		quit;

		%metadata_transassoc(omsobj=work.jobactivities, uri=jobactivities_uri, out_ref=WORK.preassign_assoc);

		proc sql;
			select assoc_uri into: ASSOC_URI_CHANGE
				from preassign_assoc;
		quit;
/*Set to 0 for not assigned and 1 to preassigned*/
		data _null_;
			rc=metadata_setattr("&ASSOC_URI_CHANGE","IsPreassigned","0");
			put rc=;
		run;

	%end;
%mend;

%change_preassignment();

/*Check the libraries have changed*/
%meta_extractlibraries(table=libraries_changed);