/**********************************************************************************************************************
 * Name:          meta_extractinfomaps.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Information Maps
 *                
 * Parameters:    Table           - Name of table to be created 
 *                LibraryName     - Optional, extract only information from this library
 *                IncludeColumns  - Yes:Include Column object information, No: Only 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractinfomaps(Table=InfoMaps);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  data &Table ;
    length tran_uri TransformRole Name $80 cUpdated $25 server $60 Type $30 ID $17;
    retain server "&server";
    Name = "";
    cUpdated = "";
    tran_uri = "";
    ID = "";
    Type = "InformationMap";

    ntran=metadata_getnobj("omsobj:transformation?@Id contains '.'",1,tran_uri);
    do c1=1 to ntran;
      rc=metadata_getnobj("omsobj:transformation?@Id contains '.'",c1,tran_uri);
      TransformRole = "";
      rc=metadata_getattr(tran_uri,"transformrole",TransformRole);
      if TransformRole ne 'InformationMap' then continue;

      rc=metadata_getattr(tran_uri,"id",ID);
      rc=metadata_getattr(tran_uri,"name",Name);
      rc=metadata_getattr(tran_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;

      * Trees;
      length Trees_uri $80 FolderName $40 ;
      FolderName = "";
      rc=metadata_getnasn(tran_uri,"Trees",1,Trees_uri);
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
      output;
    end;
    drop tran_uri TransformRole cUpdated ntran rc Trees_uri FolderName c1 ParentTree_uri ParentTree_name parentRc ;
  run;
  proc sort data=&Table ;
    by Path Name;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
