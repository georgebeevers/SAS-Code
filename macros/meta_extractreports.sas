/**********************************************************************************************************************
 * Name:          meta_extractreports.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Report objects
 *                
 * Parameters:    Table           Name of table to be created 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 * Changed:       10. Dec. 2015, Added support for Report (2G) used in Visual Analytics               
 **********************************************************************************************************************/
%macro meta_extractreports(Table=Reports);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  data &Table;
    length tran_uri PublicType Name $80 cUpdated $25 server $60 Type $30 ID $17;
    retain server "&server";
    Name = "";
    cUpdated = "";
    tran_uri = "";
    ID = "";
    Type = "Report";

    ntran=metadata_getnobj("omsobj:transformation?@Id contains '.'",1,tran_uri);
    do c1=1 to ntran;
      rc=metadata_getnobj("omsobj:transformation?@Id contains '.'",c1,tran_uri);
      PublicType = "";
      rc=metadata_getattr(tran_uri,"PublicType",PublicType);
      if PublicType ne 'Report' 
        and PublicType ne 'Report.BI' 
        and PublicType ne 'VisualDataQuery' 
      then continue;

      rc=metadata_getattr(tran_uri,"id",ID);
      rc=metadata_getattr(tran_uri,"name",Name);
      rc=metadata_getattr(tran_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;

      * Trees;
      length Trees_uri $80 FolderName $40 ;
      FolderName = "";
      rc=metadata_getnasn(tran_uri,"Trees",1,Trees_uri);
      if rc < 0 then continue;
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
    drop tran_uri cUpdated ntran rc Trees_uri FolderName c1 ParentTree_uri ParentTree_name parentRc ;
  run;
  proc sort data=&Table ;
    by Path Name;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
*meta_extractreports(Table=Reports);
