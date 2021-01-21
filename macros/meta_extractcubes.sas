/**********************************************************************************************************************
 * Name:          meta_extractcubes.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about OLAP Cubes
 *                
 * Parameters:    Table           - Name of table to be created 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractcubes(Table=Cubes);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

%let server= %scan(%sysfunc( getoption(metaserver)),1);
data &Table;
  length cube_uri job_uri Name $80 JobName $100 _Name $80 cUpdated $25 server $60 Type $30 ID $17;
  retain server " ";
  server = "&server";
  length jfjob_uri JfJobName $60 JfJobUpdated 8 source_uri $80 DeployedJobName $60;
  length dir_uri DeploymentDirectory dir_uri jobact_uri steps_uri steps_file trans_uri $80;
  job_uri = "";
  Name = "";
  cUpdated = "";
  jfjob_uri = "";
  source_uri = "";
  dir_uri = "";
  jobact_uri = "";
  steps_file = "";
  steps_uri = "";
  trans_uri = "";
  cube_uri = "";
  ID = "";
  Type = "Cube";

  ncube=metadata_getnobj("omsobj:cube?@Id contains '.'",1,cube_uri);
  do c1=1 to ncube;
    rc=metadata_getnobj("omsobj:cube?@Id contains '.'",c1,cube_uri);
    rc=metadata_getattr(cube_uri,"id",ID);
    rc=metadata_getattr(cube_uri,"Name",Name);
    rc=metadata_getattr(cube_uri,"MetadataUpdated",cUpdated);
    CubeUpdated=input(cUpdated,datetime18.5);
    format CubeUpdated datetime18.5;

    * ResponsibleParty;
    length resp_uri $80 Responsible $50;
    resp_uri = "";
    Responsible = "";
    rc=metadata_getnasn(cube_uri,"ResponsibleParties",1,resp_uri);
    if rc > 0 then do;
      rc=metadata_getattr(resp_uri,"NAME",Responsible); 
    end;

    * Trees;
    length Trees_uri $80 FolderName $40 ;
    FolderName = "";
    rc=metadata_getnasn(cube_uri,"Trees",1,Trees_uri);
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

    njob=metadata_getnobj("omsobj:job?@Id contains '.'",1,cube_uri);
    JobName = "";
    _Name = "";
    do n1=1 to njob;
      rc=metadata_getnobj("omsobj:job?@Id contains '.'",n1,job_uri);
      rc=metadata_getattr(job_uri,"NAME",_Name);
      if Name ne _Name then continue;
      JobName = _Name;
      cUpdated = "";
      Updated = .;
      rc=metadata_getattr(job_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;

      * JFJobs ;
      JfJobName = "";
      JfJobUpdated = .;
      DeployedJobName = "";
      DeployedJobLastUpdate = .;
      DeploymentDirectory = "";
      antal2=metadata_getnasn(job_uri,"JFJOBS",1,jfjob_uri);
      if antal2 > 0 then do;
        rc=metadata_getattr(jfjob_uri,"NAME",JfJobName);
        rc=metadata_getattr(jfjob_uri,"MetadataUpdated",cUpdated);
        jfJobUpdated=input(cUpdated,datetime18.5);
        format jfJobUpdated datetime18.5;
        * SourceCode;
        rc=metadata_getnasn(jfjob_uri,"SourceCode",1,source_uri);
        rc=metadata_getattr(source_uri,"NAME",DeployedJobName); 
        rc=metadata_getattr(source_uri,"MetadataUpdated",cUpdated);
        DeployedJobLastUpdate=input(cUpdated,datetime18.5);
        format DeployedJobLastUpdate datetime18.5;

        rc=metadata_getnasn(source_uri,"Directories",1,dir_uri);
        rc=metadata_getattr(dir_uri,"DirectoryName",DeploymentDirectory); 
      end;
    end;
      output;
  end;
  drop job_uri njob n1 rc jfjob_uri source_uri antal2 dir_uri jobact_uri steps_uri trans_uri steps_file
      Trees_uri ParentTree_uri cUpdated parentRc ParentTree_name FolderName _Name nCube c1 resp_uri;
run;
proc sort data=&Table;
  by Path Name;
run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
