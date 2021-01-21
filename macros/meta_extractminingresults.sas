/**********************************************************************************************************************
 * Name:          meta_extractminingresults.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Mining Results
 *                
 * Parameters:    Table           Name of table to be created 
 *                ModelKey        Unique Model Key
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractminingresults(Table=MiningResults,modelkey=);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  data &Table;
    length miningresult_uri job_uri Name JobName _Name ModelKey MiningAlgorithm MiningFunction $80 cUpdated $25 server $60 ID $17;
    retain server "&server";
    length dir_uri dir_uri jobact_uri steps_uri steps_file trans_uri $80;
    job_uri = "";
    Name = "";
    cUpdated = "";
    source_uri = "";
    dir_uri = "";
    jobact_uri = "";
    steps_file = "";
    steps_uri = "";
    trans_uri = "";
    miningresult_uri = "";
    ModelKey = "";
    MiningAlgorithm = "";
    MiningFunction = "";
    ID = "";

    nminingresult=metadata_getnobj("omsobj:MiningResult?@Id contains '.'",1,miningresult_uri);
    do c1=1 to nminingresult;
      rc=metadata_getnobj("omsobj:MiningResult?@Id contains '.'",c1,miningresult_uri);
      rc=metadata_getattr(miningresult_uri,"id",ID);
      rc=metadata_getattr(miningresult_uri,"Name",Name);
      rc=metadata_getattr(miningresult_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;
      rc=metadata_getattr(miningresult_uri,"ModelKey",ModelKey);
      rc=metadata_getattr(miningresult_uri,"MiningAlgorithm",MiningAlgorithm);
      rc=metadata_getattr(miningresult_uri,"MiningFunction",MiningFunction);

      * Trees;
      length Trees_uri $80 FolderName $40 ;
      FolderName = "";
      rc=metadata_getnasn(miningresult_uri,"Trees",1,Trees_uri);
      rc=metadata_getattr(Trees_uri,"NAME",FolderName); 

      * ParentTree;
      length Path $500 ParentTree_uri $80 ParentTree_name $40 ;
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

     * Find job;
      length specs_uri steps_uri activities_uri $80;
      drop specs_uri steps_uri activities_uri;
      specs_uri = "";
      steps_uri = "";
      activities_uri = "";
      rc=metadata_getnasn(miningresult_uri,"SpecSourceTransformations",1,specs_uri);
      if rc > 0 then do;
        rc=metadata_getnasn(specs_uri,"Steps",1,steps_uri);
        if rc > 0 then do;
          rc=metadata_getnasn(steps_uri,"Activities",1,activities_uri);
          if rc > 0 then do;
            rc=metadata_getnasn(steps_uri,"Activities",1,activities_uri);
            if rc > 0 then do;
              njob=metadata_getnasn(activities_uri,"Jobs",1, job_uri);
              JobName = "";
              _Name = "";
              do n1=1 to njob;
                rc=metadata_getnobj("omsobj:job?@Id contains '.'",n1,job_uri);
                rc=metadata_getattr(job_uri,"NAME",_Name);
                JobName = _Name;
                cUpdated = "";
                JobUpdated = .;
                rc=metadata_getattr(job_uri,"MetadataUpdated",cUpdated);
                JobUpdated=input(cUpdated,datetime18.5);
                format JobUpdated datetime18.5;

              end;
              * Trees;
              FolderName = "";
              rc=metadata_getnasn(miningresult_uri,"Trees",1,Trees_uri);
              rc=metadata_getattr(Trees_uri,"NAME",FolderName); 

              * ParentTree;
              length JobPath $500;
              JobPath = FolderName;
              ParentTree_uri = "";
              ParentTree_Name = "";
              parentRc = 1;
              do while (parentRc = 1);
                parentRc=metadata_getnasn(Trees_uri,"ParentTree",1,ParentTree_uri);
                rc=metadata_getattr(ParentTree_uri,"NAME",ParentTree_name); 
                if parentRc = 1 
                  then JobPath = trim(ParentTree_Name) || '/' || Path ;
                Trees_uri = ParentTree_uri;
              end;

            end;
          end;
        end;
      end;

      %if "&modelkey" = "" %then %do;
        output;
      %end;
      %else %do;
        if ModelKey = "&modelkey" then output;
      %end;
    end;
    drop job_uri njob n1 rc miningresult_uri source_uri dir_uri jobact_uri steps_uri trans_uri steps_file
        Trees_uri ParentTree_uri cUpdated parentRc ParentTree_name FolderName _Name nminingresult c1 ;
  run;
  proc sort data=&Table ;
    by Path Name;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
