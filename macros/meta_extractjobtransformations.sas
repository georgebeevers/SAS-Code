/**********************************************************************************************************************
 * Name:          meta_extractjobtransformations.sas
 *
 * Type:          SAS Macro
 *
 * Description:   This macro will extract job information about the specified job.
 *                The work table JobInfo will be created with one row per Transformation used in the job.
 *                The information will include the following:
 *                
 *                Name                Name of Job.
 *                Server              Name of Metadata Server.
 *                Type                Always Job.
 *                ID                  Metadata Object Id of the Job.
 *                Responsible         Name of person that updated the job the last time.
 *                Path                Folder path of the Job.
 *                StepName            Name of Step (Transformation) the read or writes the table.
 *                TableType           Type of Table where 'PhysicalTable' means a permanent table and 'Work' means a temporary table.
 *                SASTableName        Name of Table
 *                SASLibrary          Metadata Name of the SAS Library
 *                SASLibref           SAS Libref used in the libname statement.
 *                SASLibraryID        Metadata Object Id of the Library.
 *                Engine              SAS Libname engine.
 *                isDBMS              '0' means it is a SAS library, '1' means it is a non SAS Library (ie. Database)
 *                Schemaname          Name of schema if library is pointing to a database.
 *                MemberType          'DATA' means a physical table, 'VIEW' means a logical table.
 *                Step                Contains the number of the step in the job, where 1 is the first step.
 *                TransformationType  'Source' means the table is used as input, 'Target' means the table is created or updated 
 *                                    by this step.
 *                
 *                
 * Parameters:    Table           Name of table to be created 
 *                jobid           The Metadata ID of the Job, in Data Integration Studio the macro variable jobid
 *                                is set by DI Studio containing the metadata id.
 *                                If not set all jobs defined in the current metadata repository will be returned.
 *                
 * Created:       13. Feb. 2012, Michael Larse, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractjobtransformations(Table=JobTransformations,jobid=);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  %if &jobid = %then %do;
    %put NOTE: No JobId specified, extracting all jobs.;
    %let jobid=.;
  %end;
  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  data &Table;
    length job_uri Name $80 cUpdated $25 server $60;
    retain server "&server";
    length source_uri $50 ;
    length jobact_uri $50 steps_uri $50 steps_file $80 Type $30 ID $17;
    job_uri = "";
    Name = "";
    cUpdated = "";
    source_uri = "";
    dir_uri = "";
    jobact_uri = "";
    steps_file = "";
    steps_uri = "";
    trans_uri = "";
    ID = "";
    Type = "Job";
    HasBeenOutput = 0;
    njob=metadata_getnobj("omsobj:job?@Id contains '&jobid'",1,job_uri);
    if njob <= 0 then do;
      putlog "WARNING: Jobid not found in repository.";
    end;
    else do n1=1 to njob;
      rc=metadata_getnobj("omsobj:job?@Id contains '&jobid'",n1,job_uri);
      rc=metadata_getattr(job_uri,"id",ID);
      rc=metadata_getattr(job_uri,"NAME",Name);
      rc=metadata_getattr(job_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;

      * ResponsibleParty;
      length resp_uri $50 Responsible $50;
      resp_uri = "";
      Responsible = "";
      rc=metadata_getnasn(job_uri,"ResponsibleParties",1,resp_uri);
      if rc > 0 then do;
        rc=metadata_getattr(resp_uri,"NAME",Responsible); 
      end;

      * Trees;
      length Trees_uri $80 FolderName $40 ;
      FolderName = "";
      rc=metadata_getnasn(job_uri,"Trees",1,Trees_uri);
      rc=metadata_getattr(Trees_uri,"NAME",FolderName); 

      * ParentTree;
      length Path $500 ParentTree_uri $50 ParentTree_name $40 ;
      Path = FolderName;
      ParentTree_uri = "";
      ParentTree_Name = "";
      parentRc = 1;
      do while (parentRc = 1);
        parentRc=metadata_getnasn(Trees_uri,"ParentTree",1,ParentTree_uri);
        rc=metadata_getattr(ParentTree_uri,"NAME",ParentTree_name); 
        if parentRc = 1 
          then Path = trim(ParentTree_Name) || '/' || Path ;
        Trees_uri = ParentTree_uri;
      end;

      * Steps and Target Tables;
      length acts_uri $50 step_uri $50 StepName $200;
      length TableType $100 TargetName $100 SASTableName $100 TableID $17 tpack_uri $50 SASLibrary $100 SASLibref $40
             SASLibraryID $50 upack_uri $50 package_uri $50 dirname Directory $300 Engine $20 isPreassigned $1
              isDBMS $1 schema_uri $50 SchemaName $50 MemberType $4 TransformationIsUserDefined $1 TransformRole $100
              Cvalue $20;
      call missing(acts_uri,step_uri,StepName,TransformationIsUserDefined,TransformRole,Cvalue);
      rc=metadata_getnasn(job_uri,"CustomAssociations",1,acts_uri);
      do custno=1 to rc;
        rc=metadata_getnasn(job_uri,"CustomAssociations",custno,acts_uri);
        rc=metadata_getattr(acts_uri,"NAME",Cvalue); 
        if Cvalue = "ControlOrder" then leave;
      end;
      steps=metadata_getnasn(acts_uri,"AssociatedObjects",1,step_uri);

      do Step=1 to Steps;
        rc=metadata_getnasn(acts_uri,"Steps",Step,step_uri);
        rc=metadata_getattr(step_uri,"NAME",StepName); 
        rc=metadata_getattr(step_uri,"IsUserDefined",TransformationIsUserDefined); 
        rc=metadata_getattr(step_uri,"TransformRole",TransformRole); 
        length steptran_uri $50 class_uri $50 ;
        steptran_uri = "";
        class_uri = "";
        rc=metadata_getnasn(step_uri,"Transformations",1,steptran_uri);

        /* Find Source Tables */
        associationType = "ClassifierSources";
        TransformationType = 'Source';
        link TableInfo;

        /* Find Target Tables */
        associationType = "ClassifierTargets";
        TransformationType = 'Target';
        link TableInfo;
      end;

      if HasBeenOutput = 0 then output; /* Output a row even if job has no source or target tables */
    end;
    drop njob rc source_uri dir_uri jobact_uri steps_uri trans_uri steps_file job_uri target HasBeenOutput
        Trees_uri ParentTree_uri cUpdated parentRc ParentTree_name FolderName resp_uri steps targets acts_uri step_uri steptran_uri
        tpack_uri class_uri upack_uri dir dirs dirname n1 package_uri schema_uri associationtype cvalue custno ;
    return;

    TableInfo:
        targets=metadata_getnasn(steptran_uri,associationType,1,class_uri);
        do target=1 to targets;
          TableType = ""; 
          TargetName = "";
          SASTableName = "";
          TableID = "";
          MemberType = "";
          rc=metadata_getnasn(steptran_uri,associationType,target,class_uri);
          rc=metadata_resolve(class_uri,TableType,TableID); 
          rc=metadata_getattr(class_uri,"NAME",TargetName); 
          rc=metadata_getattr(class_uri,"id",TableID);
          rc=metadata_getattr(class_uri,"SASTableName",SASTableName); 
          rc=metadata_getattr(class_uri,"MemberType",MemberType);
          SASLibrary = "WORK";
          SASLibref = "WORK";
          tpack_uri = "";
          upack_uri = "";
          rc=metadata_getnasn(class_uri,"TablePackage",1,tpack_uri);
          if rc > 0 then do;
            Engine = "";
            isDBMS = "";
            isPreAssigned = "";
            SASLibraryID = "";
            rc=metadata_getattr(tpack_uri,"Name",SASLibrary); 
            rc=metadata_getattr(tpack_uri,"Engine",Engine); 
            rc=metadata_getattr(tpack_uri,"Libref",SASLibref);     
            rc=metadata_getattr(tpack_uri,"ID",SASLibraryID);
            rc=metadata_getattr(tpack_uri,"isPreassigned",isPreAssigned); 

            SchemaName = '';
            package_uri = "";
              schema_uri = "";
            rc=metadata_getnasn(tpack_uri,"UsedByPackages",1,package_uri); 
            if rc = 0 then do;
              rc=metadata_getnasn(package_uri,"UsingPackages",1,schema_uri); 
              rc=metadata_getattr(schema_uri,"SchemaName",SchemaName); 
            end;
            rc=metadata_getattr(package_uri,"isDBMSLibname",isDBMS); 

            if isDBMS ne '1' then isDBMS = '0';

            Directory = "";
            dirs=metadata_getnasn(tpack_uri,"UsingPackages",1,upack_uri);
            do dir=1 to dirs;
              rc=metadata_getnasn(tpack_uri,"UsingPackages",dir,upack_uri);
              rc=metadata_getattr(upack_uri,"DirectoryName",dirname); 
              dirname = catt('"',dirname,'"');
              Directory = catt(Directory,' ',dirname);
            end;
          end;
          output;
          HasBeenOutput = 1;
        end;
    return;
  run;
  proc sort data=&Table ;
    by Path Name ;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
