/**********************************************************************************************************************
 * Name:          meta_extractjobtables.sas
 *
 * Type:          SAS Macro
 *
 * Description:   This macro will extract job information about the specified job.
 *                The work table JobInfo will be created with one row per Source or Target table defined in a job.
 *                The information will include the following:
 *                
 *                Name                Name of Job.
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
 * Created:       13. Feb. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractjobtables(Table=JobTables,jobid=, subjobtable=);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  %if &jobid = %then %do;
    %put NOTE: No JobId specified, extracting all jobs.;
    %let jobid=.;
  %end;
  %if "&subjobtable" = "" %then %do;
    %if %sysfunc(exist(&Table)) %then %do;
      proc delete data=&Table ;
      run;
    %end;
  %end;
  data _jobs _subjobs(keep=Name StepID);
    length t_job_uri Name $80 t_cUpdated $25 ;
    length t_source_uri $50 StepType $30 StepID $17;
    length t_jobact_uri $50 t_steps_uri $50 t_steps_file $80 Type $30 ID $17;
    call missing(t_job_uri, Name, t_cUpdated, t_source_uri, t_dir_uri, t_jobact_uri, t_steps_file, t_steps_uri, t_trans_uri, ID, StepID);
    Type = "Job";
    %if &subjobtable ne %then %do;
      set &subjobtable;
      t_njob=metadata_getnobj("omsobj:job?@Id contains '"||StepID||"'",1,t_job_uri);
    %end;
    %else %do;
      t_njob=metadata_getnobj("omsobj:job?@Id contains '&jobid'",1,t_job_uri);
    %end;
    if t_njob <= 0 then do;
      putlog "WARNING: Jobid not found in repository.";
    end;
    else do t_n1=1 to t_njob;
      t_HasBeenOutput = 0;
    %if &subjobtable ne %then %do;
      t_njob=metadata_getnobj("omsobj:job?@Id contains '"||StepID||"'",1,t_job_uri);
    %end;
    %else %do;
      t_rc=metadata_getnobj("omsobj:job?@Id contains '&jobid'",t_n1,t_job_uri);
    %end;
      t_rc=metadata_getattr(t_job_uri,"id",ID);
      t_rc=metadata_getattr(t_job_uri,"NAME",Name);
      t_rc=metadata_getattr(t_job_uri,"MetadataUpdated",t_cUpdated);
      Updated=input(t_cUpdated,datetime18.5);
      format Updated datetime18.5;

      * ResponsibleParty;
      length t_resp_uri $50 Responsible $50;
      call missing(t_resp_uri, Responsible);
      t_rc=metadata_getnasn(t_job_uri,"ResponsibleParties",1,t_resp_uri);
      if t_rc > 0 then do;
        t_rc=metadata_getattr(t_resp_uri,"NAME",Responsible); 
      end;

      * Trees;
      length t_Trees_uri $80 FolderName $40 ;
      call missing(FolderName);
      t_rc=metadata_getnasn(t_job_uri,"Trees",1,t_Trees_uri);
      t_rc=metadata_getattr(t_Trees_uri,"NAME",FolderName); 

      * ParentTree;
      length Path $500 t_ParentTree_uri $50 t_ParentTree_name $40 ;
      Path = FolderName;
      call missing(t_ParentTree_uri, t_ParentTree_name);
      t_parentRc = 1;
      do while (t_parentRc = 1);
        t_parentRc=metadata_getnasn(t_Trees_uri,"ParentTree",1,t_ParentTree_uri);
        t_rc=metadata_getattr(t_ParentTree_uri,"NAME",t_ParentTree_name); 
        if t_parentRc = 1 
          then Path = trim(t_ParentTree_name) || '/' || Path ;
        t_Trees_uri = t_ParentTree_uri;
      end;

      * Steps, Source and Target Tables;
      length t_acts_uri $50 t_step_uri $50 StepName $200;
      length TableType $100 TargetName $100 SASTableName $100 TableID $17 t_tpack_uri $50 SASLibrary $100 SASLibref $40
             SASLibraryID $50 t_upack_uri $50 t_package_uri $50 t_dirname Directory $300 Engine $20 isPreassigned $1
              isDBMS $1 t_schema_uri $50 SchemaName $50 MemberType $4 TransformationType $6;
      call missing(t_acts_uri, t_step_uri, StepName);
      t_rc=metadata_getnasn(t_job_uri,"JobActivities",1,t_acts_uri);
      t_steps=metadata_getnasn(t_acts_uri,"Steps",1,t_step_uri);
      do t_stepno=1 to t_steps;
        t_rc=metadata_getnasn(t_acts_uri,"Steps",t_stepno,t_step_uri);
        t_rc=metadata_getattr(t_step_uri,"NAME",StepName); 
        length t_steptran_uri $50 t_class_uri t_associationType $50 ;
        call missing(t_steptran_uri, t_class_uri, StepType, StepID, TableType, TargetName, SASTableName, TableID, MemberType,
                     SASLibrary, SASLibref, Engine, isDBMS, isPreAssigned, SASLibraryID, SchemaName, Directory, 
                     MemberType, TransformationType, MemberType);
        t_rc=metadata_getnasn(t_step_uri,"Transformations",1,t_steptran_uri);
        t_rc=metadata_getattr(t_step_uri,"ID",StepID);

        /* Get the ControlOrder */
        length t_ref_uri t_con_uri t_jobtran_uri $50 t_subid $17;
        call missing(t_con_uri, t_subid, t_ref_uri, t_jobtran_uri);
        t_rc=metadata_getnasn(t_step_uri,"ReferencedObjects",1,t_ref_uri);
        t_substeps=metadata_getnasn(t_ref_uri,"AssociatedObjects",1,t_con_uri);
        do t_substep=1 to t_substeps;
          t_substeps=metadata_getnasn(t_ref_uri,"AssociatedObjects",t_substep,t_con_uri);
          Step = t_substep;
          t_rc=metadata_getattr(t_con_uri,"ID",t_subid); 
          if StepId = t_subid then leave;
        end;

        t_rc=metadata_getattr(t_steptran_uri,"PublicType",StepType);
        if StepType = '' then t_rc = metadata_getattr(t_steptran_uri,"Name",StepType);
        if StepType = 'Job' and StepID ne '' then do;
          t_rc=metadata_getattr(t_steptran_uri,"ID",StepID);
          TransformationType = "SubJob";
           output _subjobs;
           output _jobs;
           continue;
        end;

        /* Find Source Tables */
        t_associationType = "ClassifierSources";
        TransformationType = 'Source';
        link TableInfo;

        /* Find Target Tables */
        t_associationType = "Classifiertargets";
        TransformationType = 'Target';
        link TableInfo;
      end;

      if t_HasBeenOutput = 0 then do;
        Step = Step - 1;
        output _jobs; /* Output a row even if job has no source or target tables */
      end;
    end;
    drop t_: ;
    return;

    TableInfo:
        t_targets=metadata_getnasn(t_steptran_uri,t_associationType,1,t_class_uri);
        do t_target=1 to t_targets;
          call missing(TableType, TargetName, SASTableName, TableID, MemberType);
          t_rc=metadata_getnasn(t_steptran_uri,t_associationType,t_target,t_class_uri);
          t_rc=metadata_resolve(t_class_uri,TableType,TableID); 
          t_rc=metadata_getattr(t_class_uri,"NAME",TargetName); 
          t_rc=metadata_getattr(t_class_uri,"id",TableID);
          t_rc=metadata_getattr(t_class_uri,"TableName",SASTableName); 
          t_rc=metadata_getattr(t_class_uri,"MemberType",MemberType);
          if TableType ne 'ExternalTable' then do;
            SASLibrary = "WORK";
            SASLibref = "WORK";
          end;
          else do;
            call missing(SASLibrary, SASLibref);
            MemberType = "FILE";
          end;
          call missing(t_tpack_uri, t_upack_uri, Engine, SASLibraryID, SchemaName, t_package_uri, t_schema_uri, Directory);
          isDBMS = "0";
          isPreAssigned = "0";
          if MemberType ne 'FILE' then do;
            t_rc=metadata_getnasn(t_class_uri,"TablePackage",1,t_tpack_uri);
            if t_rc > 0 then do;
              t_rc=metadata_getattr(t_tpack_uri,"Name",SASLibrary); 
              t_rc=metadata_getattr(t_tpack_uri,"Engine",Engine); 
              t_rc=metadata_getattr(t_tpack_uri,"Libref",SASLibref);     
              t_rc=metadata_getattr(t_tpack_uri,"ID",SASLibraryID);
              t_rc=metadata_getattr(t_tpack_uri,"isPreassigned",isPreAssigned); 

              t_rc=metadata_getnasn(t_tpack_uri,"UsedByPackages",1,t_package_uri); 
              if t_rc = 0 then do;
                t_rc=metadata_getattr(t_package_uri,"Name",SASLibrary); 
                t_rc=metadata_getattr(t_package_uri,"Engine",Engine); 
                t_rc=metadata_getattr(t_package_uri,"Libref",SASLibref);     
                t_rc=metadata_getattr(t_package_uri,"ID",SASLibraryID);
                t_rc=metadata_getattr(t_package_uri,"isPreassigned",isPreAssigned); 
                t_rc=metadata_getnasn(t_package_uri,"UsingPackages",1,t_schema_uri); 
                t_rc=metadata_getattr(t_package_uri,"isDBMSLibname",isDBMS); 
                t_rc=metadata_getattr(t_schema_uri,"SchemaName",SchemaName); 
              end;

              if isDBMS ne '1' then isDBMS = '0';

              t_dirs=metadata_getnasn(t_tpack_uri,"UsingPackages",1,t_upack_uri);
              do t_dir=1 to t_dirs;
                t_rc=metadata_getnasn(t_tpack_uri,"UsingPackages",t_dir,t_upack_uri);
                t_rc=metadata_getattr(t_upack_uri,"DirectoryName",t_dirname); 
                t_dirname = catt('"',t_dirname,'"');
                Directory = catt(Directory,' ',t_dirname);
              end;
            end;
          end;
          else do;
            t_rc=metadata_getnasn(t_class_uri,"OwningFile",1,t_tpack_uri);
            length t_file_uri $100;
            t_file_uri = "";
            t_rc=metadata_getnasn(t_tpack_uri,"FileRefs",1,t_file_uri);
            if t_rc > 0 then 
              t_rc=metadata_getattr(t_file_uri,"Name",Directory); 
          end;
          output _jobs;
          t_HasBeenOutput = 1;
        end;
    return;
  run;
  proc append base=&Table data=_jobs ;
  run;
  proc sort data=&Table nodup ;
    by Path Name ID TableID StepType;
  run;

  data _null_;
    set _subjobs;
    if _n_ = 1 then do;
      call execute('%meta_extractjobtables(table='
            ||"&table"
            ||',subjobtable=_subjobs);'
                   );
      stop;
    end;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
