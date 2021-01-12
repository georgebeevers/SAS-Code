/*************************************************************************************************************/
/*  PROGRAM NAME: META_EXTRACTJOBS   	                                    								 */
/*  DATE CREATED: 15/12/2020                                                      							 */
/*  AUTHOR: GEORGE BEEVERS																					 */
/*  DESCRIPTION: EXTRACT ALL JOBS HELD IN METADATA															 */
/*  MACROS:								  |              					                        		 */
/* --------------------------------------------------------------------------------------------------------- */
/*  VERSION CONTROL		                                                         							 */
/*  V1.0 15/12/2020 INITIAL VERSION GEORGE BEEVERS                                 							 */
/* --------------------------------------------------------------------------------------------------------- */
%macro meta_extractjobs(Table=);
	%let server= %scan(%sysfunc( getoption(metaserver)),1);

	data &Table;
		length job_uri Name $80 cUpdated $25 server $60;
		retain server "&server";
		length jfjob_uri JfName $60 JfJobUpdated 8 source_uri $80 DeployedName $60;
		length dir_uri deploy_uri ServerContext $80 DeploymentDirectoryLogicalName $100 DeploymentDirectory $500 
			dir_uri jobact_uri steps_uri steps_file trans_uri $80 Type $25 ID JfID $17 JFType $30;
		call missing(job_uri,Name,cUpdated,jfjob_uri,source_uri,dir_uri,jobact_uri,steps_file,steps_uri,trans_uri,ID,JfID);
		Type = "Job";
		njob=metadata_getnobj("omsobj:job?@Id contains '.'",1,job_uri);

		do n1=1 to njob;
			rc=metadata_getnobj("omsobj:job?@Id contains '.'",n1,job_uri);
			rc=metadata_getattr(job_uri,"id",ID);
			rc=metadata_getattr(job_uri,"NAME",Name);
			rc=metadata_getattr(job_uri,"MetadataUpdated",cUpdated);
			JobUpdated=input(cUpdated,datetime18.5);
			format JobUpdated datetime18.5;

			* JFJobs;
			call missing(JfName,JfJobUpdated,DeployedName,DeployedJobLastUpdate,DeploymentDirectory,DeploymentDirectoryLogicalName,ServerContext,
				deploy_uri,JfID,JFType);
			antal2=metadata_getnasn(job_uri,"JFJOBS",1,jfjob_uri);

			if antal2 > 0 then
				do;
					JFType = "DeployedJob";
					rc=metadata_getattr(jfjob_uri,"ID",JfID);
					rc=metadata_getattr(jfjob_uri,"NAME",JfName);
					rc=metadata_getattr(jfjob_uri,"MetadataUpdated",cUpdated);
					jfJobUpdated=input(cUpdated,datetime18.5);
					format jfJobUpdated datetime18.5;

					* SourceCode;
					rc=metadata_getnasn(jfjob_uri,"SourceCode",1,source_uri);
					rc=metadata_getattr(source_uri,"NAME",DeployedName);
					rc=metadata_getattr(source_uri,"MetadataUpdated",cUpdated);
					DeployedJobLastUpdate=input(cUpdated,datetime18.5);
					format DeployedJobLastUpdate datetime18.5;
					rc=metadata_getnasn(source_uri,"Directories",1,dir_uri);
					rc=metadata_getattr(dir_uri,"Name",DeploymentDirectoryLogicalName);
					rc=metadata_getattr(dir_uri,"DirectoryName",DeploymentDirectory);
					rc=metadata_getnasn(dir_uri,"DeployedComponents",1,deploy_uri);
					rc=metadata_getattr(deploy_uri,"Name",ServerContext);
				end;

			* ResponsibleParty;
			length resp_uri $80 Responsible $50;
			resp_uri = "";
			Responsible = "";
			rc=metadata_getnasn(job_uri,"ResponsibleParties",1,resp_uri);

			if rc > 0 then
				do;
					rc=metadata_getattr(resp_uri,"NAME",Responsible);
				end;

			* Trees;
			length Trees_uri $80 FolderName $40;
			FolderName = "";
			rc=metadata_getnasn(job_uri,"Trees",1,Trees_uri);
			rc=metadata_getattr(Trees_uri,"NAME",FolderName);

			* ParentTree;
			length Path $500 ParentTree_uri $80 ParentTree_name $40;
			Path = FolderName;
			ParentTree_uri = "";
			ParentTree_Name = "";
			parentRc = 1;

			do while (parentRc = 1);
				parentRc=metadata_getnasn(Trees_uri,"ParentTree",1,ParentTree_uri);
				rc=metadata_getattr(ParentTree_uri,"NAME",ParentTree_name);

				if parentRc = 1 then
					Path = trim(ParentTree_Name) || '/' || Path;
				Trees_uri = ParentTree_uri;
			end;

			output;
		end;

		drop njob n1 rc jfjob_uri source_uri antal2 dir_uri jobact_uri steps_uri trans_uri steps_file
			Trees_uri ParentTree_uri cUpdated parentRc ParentTree_name FolderName resp_uri deploy_uri
			job_uri;
	run;

	proc sort data=&Table;
		by Path Name;
	run;

%mend;