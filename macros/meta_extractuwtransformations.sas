/**********************************************************************************************************************
 * Name:          meta_extractuwtransformations.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about User Written Transformations
 *                
 * Parameters:    Table           - Name of table to be created 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractuwtransformations(Table=UWTransformations);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  data &Table;
    length tran_uri TransformRole Name $80 cUpdated $25 server $60 Type $30 ID $17;
    retain server "&server";
    Name = "";
    cUpdated = "";
    tran_uri = "";
    ID = "";
    Type = "GeneratedTransform";

    ntran=metadata_getnobj("omsobj:prototype?@Id contains '.'",1,tran_uri);
    do c1=1 to ntran;
      rc=metadata_getnobj("omsobj:prototype?@Id contains '.'",c1,tran_uri);
      TransformRole = "";

      rc=metadata_getattr(tran_uri,"PublicType",TransformRole);
      if TransformRole ne Type then continue;

      rc=metadata_getattr(tran_uri,"id",ID);
      rc=metadata_getattr(tran_uri,"name",Name);

      * ResponsibleParty;
      length resp_uri $80 Responsible $50;
      resp_uri = "";
      Responsible = "";
      rc=metadata_getnasn(tran_uri,"ResponsibleParties",1,resp_uri);
      if rc > 0 then do;
        rc=metadata_getattr(resp_uri,"NAME",Responsible); 
      end;

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

      /* Get the date for last modified */
      length property_uri $80 PropName $30 Class $50;
      call missing(cUpdated,Propname,Property_uri,Class);
      propertyno=metadata_getnasn(tran_uri,"Properties",1,property_uri);
      do t=1 to propertyno;
        rc=metadata_getnasn(tran_uri ,"Properties",t,property_uri);
        rc=metadata_getattr(property_uri,"Name",PropName);
        if PropName = 'TransformationTemplate' then
          rc=metadata_getattr(property_uri,"MetadataUpdated",cUpdated);
        else if Propname = 'Class' then do;
          rc=metadata_getattr(property_uri,"DefaultValue",Class);
        end;
        else if PropName = 'VERSION' then ;
      end;
      Updated=input(cUpdated,datetime18.5);
      format Updated datetime18.5;
      output;
    end;
    drop tran_uri TransformRole cUpdated ntran rc Trees_uri FolderName c1 ParentTree_uri ParentTree_name parentRc property_uri propertyno t PropName resp_uri;
  run;
  proc sort data=&Table ;
    by Path Name;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);
%mend;
