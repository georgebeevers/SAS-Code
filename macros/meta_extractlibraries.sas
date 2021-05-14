/**********************************************************************************************************************
 * Name:          meta_extractlibraries.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Libraries
 *                
 * Parameters:    Table           - Name of table to be created 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extractlibraries(Table=Libraries);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;

  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  %let Repository= %sysfunc(compress (%sysfunc( getoption(metarepository)),'"'));
  %put NOTE: Extracting information from Metadata Server: &Server, Repository: &Repository ;
  data &Table ;
   
    length lib_uri package_uri schema_uri Trees_uri $80 
      name $80 engine $20 
      isDBMS $1 isPreassigned $1 Id $17
      source_uri saslib_uri sasvar_uri $80
      SchemaName $40 libref $10 FolderName $500
      Updated 8 cUpdated $25 Server $60 Repository $60 Type $30  
      Location $1000  Path $500 ParentTree_uri $80 ParentTree_name $40     ;
    retain server "&server" Repository "%unquote(&Repository)";

    Type = "Library";
    call missing(lib_uri,name,engine,libref,isDBMS,isPreassigned,Id,source_uri,saslib_uri,
                 sasvar_uri,Updated,cUpdated,package_uri,schema_uri,SchemaName, Location);

    nlib=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",1,lib_uri); 
    if nlib <= 0 then
      put 'WARNING: Did not find any libraries in Metadata Server.';
    else
      put 'NOTE: Found ' nlib 'libraries in Metadata Server.';

    do nlibs=1 to nlib;

      lib_obj=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",nlibs,lib_uri); 

      rc=metadata_getattr(lib_uri,"Id",Id); 
      rc=metadata_getattr(lib_uri,"Name",name); 
      rc=metadata_getattr(lib_uri,"Engine",engine); 
      rc=metadata_getattr(lib_uri,"Libref",libref);     
      rc=metadata_getattr(lib_uri,"isDBMSLibname",isDBMS); 
      rc=metadata_getattr(lib_uri,"isPreassigned",isPreAssigned); 
      rc=metadata_getattr(lib_uri,"MetadataUpdated",cUpdated); 
      Updated=input(cUpdated,datetime18.5);

      * ResponsibleParty;
      length resp_uri $80 Responsible $50;
      resp_uri = "";
      Responsible = "";
      rc=metadata_getnasn(lib_uri,"ResponsibleParties",1,resp_uri);
      if rc > 0 then do;
        rc=metadata_getattr(resp_uri,"NAME",Responsible); 
      end;

      /* Generate Path */
      call missing(ParentTree_uri,ParentTree_name,FolderName);
      rc=metadata_getnasn(lib_uri,"Trees",1,Trees_uri);
      rc=metadata_getattr(Trees_uri,"NAME",FolderName); 

      Path = FolderName;
      parentRc = 1;
      do while (parentRc = 1);
        parentRc=metadata_getnasn(Trees_uri,"ParentTree",1,ParentTree_uri);
        rc=metadata_getattr(ParentTree_uri,"NAME",ParentTree_name); 
        if parentRc = 1 
          then Path = trim(ParentTree_Name) || '/' || Path ;
        Trees_uri = ParentTree_uri;
      end;

      /* Get LibraryConnection */
      length attr_uri Connection_uri source_uri $80 AuthDomain ServerContext ConnectionName $150;
      call missing(attr_uri, AuthDomain,ConnectionName,Connection_uri,source_uri,ServerContext);
      packages=metadata_getnasn(lib_uri,"LibraryConnection",1,Connection_uri);
      do p=1 to packages;
        rc=metadata_getnasn(lib_uri,"LibraryConnection",p,Connection_uri);
                rc=metadata_getattr(Connection_uri,"Name",ConnectionName); 
        rc=metadata_getnasn(Connection_uri,"Domain",p,attr_uri);
                if rc > 0 then 
        rc=metadata_getattr(attr_uri,"Name",AuthDomain); 
        rc=metadata_getnasn(Connection_uri,"Source",p,source_uri);
                if rc > 0 then 
        rc=metadata_getattr(source_uri,"Name",ServerContext); 
      end;

      /* Get UsingPackages */
      packages=metadata_getnasn(lib_uri,"UsingPackages",1,package_uri); 
      do p=1 to packages;
        rc=metadata_getnasn(lib_uri,"UsingPackages",p,package_uri); 
        call missing(Location,Schemaname);
        if isDBMS = '1' then do;
          rc = metadata_getattr(package_uri,"DirectoryName",Location);
          rc=metadata_getattr(package_uri,"SchemaName",SchemaName); 
          rc=metadata_getnobj(package_uri,1,schema_uri); 
        end;
        else rc = metadata_getattr(package_uri,"DirectoryName",Location);
        output;
      end;
    end;

    drop lib_uri nlibs rc nlib lib_obj saslib_uri sasvar_uri package_uri schema_uri packages p
         source_uri cUpdated Trees_uri ParentTree_uri ParentTree_Name parentRc FolderName resp_uri
                 attr_uri Connection_uri source_uri
       ;
    format Updated datetime. ;
  run;
  proc sort data=&Table ;
    by Path Name ;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);

%mend;



