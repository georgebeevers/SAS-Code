%macro meta_get_workspace(table=);
	/* Count how many Object Spawners are defined in WORK.OBJSPAWN as a Macro variable. */
	proc sql noprint;
		select count(*) into :nobjs from work.objspawn;
	quit;

	%if &nobjs > 0 %then
		%do;
			/* If hosts were found, extract them as macro variables. */
			proc sql noprint;
				select host_name into:host1-:host%left(&nobjs) from work.objspawn;
				select port into:port1-:port%left(&nobjs) from work.objspawn;
			quit;

		%end;
	%else; /* Create base tables. */

	data work.wkspc;
		length SERVERCOMPONENT LOGICALNAME $50 SERVERCLASS PROCESSOWNER SERVERID $36;
		call missing(of _character_);

		if compress(cats(of _all_),'.')=' ' then
			delete;
	run;

	data work.wkspcidle;
		length SERVERCOMPONENT LOGICALNAME $50 SERVERCLASS PROCESSOWNER SERVERID $36 CATEGORY NAME $ 1024 VALUE $ 4096;
		call missing(of _character_);
		if compress(cats(of _all_),'.')=' ' then
			delete;
	run;

	/* Connect to each object spawner to get the workspace servers it has spawned, output them to a dataset. */
	%do i=1 %to &nobjs;

		proc iomoperate;
			connect host="&&host&i" port=&&port&i user="&metauser" pass="&metapass" servertype=OBJECTSPAWNER;
			LIST SPAWNED SERVERS out=wkspc&i;
		quit; 
		/* Count the number of total workspace servers were found. */
		proc sql noprint;
			select count(*) into :nwkspc from work.wkspc&i;
		quit; 
		/* If any were found, add them to the wkspc dataset. */
		%if &nwkspc > 0 %then
			%do;

				proc sql;
					insert into work.wkspc select * from work.wkspc&i;
				quit;

			%end; 
			/* If any were found, gather their IdleTime value. */

		%if &nwkspc > 0 %then
			%do j=1 %to &nwkspc;

				proc sql noprint;
					select SERVERID into:server_id1-:server_id%left(&nwkspc) from work.wkspc&i;
				quit;

				proc iomoperate;
					connect host="&&host&i" port=&&port&i user="&metauser" pass="&metapass" servertype=OBJECTSPAWNER spawned="&&server_id&j";
					LIST ATTRIBUTE Category="Counters" Name="IOM.IdleTime" out=work.wkspci&j;
				quit; 
		/* Add the server ID to the table containing the idle time. */

				data work.wkspci&j;
					set work.wkspci&j;
					server_id="&&server_id&j";
				run; 
		/* Join the spawned servers table for the spawner with the idle time. */

				proc sql noprint;
					create table work.idle&j as select * from work.wkspc&i,work.wkspci&j where
						SERVERID=server_id;
				quit;

		/* Append the new table of server and idle time to a master table. */
				proc sql;
					insert into work.wkspcidle 
						select 
							SERVERCOMPONENT, 
							LOGICALNAME, 
							SERVERCLASS, 
							PROCESSOWNER, 
							SERVERID, 
							CATEGORY, 
							NAME, 
							VALUE 
						from work.idle&j;
				quit;

			%end;
			/*				Clean up*/
				proc datasets lib=work;
				delete wkspc&i;
				delete wkspci&j;
				delete idle:;
				run;
	%end;
/*Clean up*/
	data work.&table.;
	set work.wkspcidle;
	keep SERVERCOMPONENT LOGICALNAME SERVERCLASS PROCESSOWNER SERVERID idle_time_secs idle_time_mins;
	idle_time_secs=round(input(VALUE,8.));
	idle_time_mins=round((input(VALUE,8.)/60));
run;
Proc datasets lib=work;
/*delete objspawn;*/
delete wkspc:;
run;
/*delete idle:;*/
%mend;