/**********************************************************************************************************************
 * Name:          meta_extractprompts.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Prompts
 *                
 * Parameters:    Table           - Name of table to be created 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractPrompts(Table=Prompts);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  data &Table;
    length meta_uri Name $80 cUpdated $25 ID $17;
    call missing(of _all_);
    Type = "Prompt";
    njob=metadata_getnobj("omsobj:prompt?@Id contains '.'",1,meta_uri);
    do n1=1 to njob;
      rc=metadata_getnobj("omsobj:prompt?@Id contains '.'",n1,meta_uri);
      rc=metadata_getattr(meta_uri,"id",ID);
      rc=metadata_getattr(meta_uri,"NAME",Name);
      rc=metadata_getattr(meta_uri,"MetadataUpdated",cUpdated);
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;

      * ResponsibleParty;
      length resp_uri $80 Responsible $50;
      resp_uri = "";
      Responsible = "";
      rc=metadata_getnasn(meta_uri,"ResponsibleParties",1,resp_uri);
      if rc > 0 then do;
        rc=metadata_getattr(resp_uri,"NAME",Responsible); 
      end;

      rc=metadata_getnasn(meta_uri,"AssociatedLogins",1,resp_uri);
put Name= rc= resp_uri=;
      if rc > 0 then do;
        rc=metadata_getattr(resp_uri,"NAME",Responsible); 
      end;


      * Trees;
      length Trees_uri $80 FolderName $40 ;
      FolderName = "";
      rc=metadata_getnasn(meta_uri,"Trees",1,Trees_uri);
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
    drop njob n1 rc 
        Trees_uri ParentTree_uri cUpdated parentRc ParentTree_name FolderName resp_uri meta_uri;
  run;
  proc sort data=&Table ;
    by Path Name;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;
/*%meta_extractprompts;*/
