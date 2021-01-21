/**********************************************************************************************************************
 * Name:          meta_extractfolders.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Folders
 *                
 * Parameters:    Table           - Name of table to be created 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractfolders(Table=Folders);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  data &Table;
    length folder_uri Folder $80 ID $17 cUpdated $25 server PublicType TreeType $60 Type $30 Path $500;
    drop folder_uri n1 rc cUpdated PublicType TreeType nfolder;
    retain server "&server";
    folder_uri = "";
    Folder = "";
    cUpdated = "";
    ID = "";
    Type = "Folder";
    PublicType = "";
    TreeType = "";
    nfolder=metadata_getnobj("omsobj:tree?@Id contains '.'",1,folder_uri);
    do n1=1 to nfolder;
      rc=metadata_getnobj("omsobj:tree?@Id contains '.'",n1,folder_uri);
      rc=metadata_getattr(folder_uri,"id",ID);
      rc=metadata_getattr(folder_uri,"NAME",Folder);
      rc=metadata_getattr(folder_uri,"PublicType",PublicType);
      rc=metadata_getattr(folder_uri,"TreeType",TreeType);
      rc=metadata_getattr(folder_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;
      if PublicType = 'Folder' and TreeType = 'BIP Folder' then do;
        * ParentTree;
        length Path $500 ParentTree_uri $80 ParentFolder $200 RootID ParentID $17;
        drop ParentTree_uri parentRC Trees_uri ParentFolder RootID ;
        Path = Folder;
        ParentTree_uri = "";
        RootID = "";
        ParentFolder = "";
        ParentID = "";
        Trees_uri = folder_uri;
        parentRc = 1;
        do while (parentRc = 1);
          parentRc=metadata_getnasn(Trees_uri,"ParentTree",1,ParentTree_uri);
          if ParentID = "" then rc=metadata_getattr(ParentTree_uri,"id",ParentID);
          rc=metadata_getattr(ParentTree_uri,"NAME",ParentFolder); 
          if parentRc = 1 then Path = trim(ParentFolder) || '/' || Path ;
          Trees_uri = ParentTree_uri;
        end;
        output;
      end;
    end;
  run;
  proc sort data=&Table ;
    by Path Folder;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
