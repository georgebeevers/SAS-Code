/**********************************************************************************************************************
 * Name:          meta_extracttables.sas
 *
 * Type:          Macro
 *
 * Description:   Extracts information from Metadata Server about Tables and Columns
 *                
 * Parameters:    Table           - Name of table to be created 
 *                LibraryName     - Optional, extract only information from this library
 *                IncludeColumns  - Yes:Include Column object information, No: Only 
 *                
 * Created:       23. Mar. 2012, Michael Larsen, SAS Institute
 *                
 **********************************************************************************************************************/
%macro meta_extracttables(Table=Tables,LibraryName=, IncludeColumns=No);
%options_remember(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N); 
options linesize=256 nomlogic nomprint nonotes pagesize=1024 nosymbolgen;
  %if "&LibraryName" eq "" %then %put NOTE: No library name specified, will return all libraries.;
  %else %put NOTE: Searching for Library named "&LibraryName"...;
  %if %str(&IncludeColumns) = %str() %then
    %let IncludeColumns = NO;
  %let IncludeColumns = %upcase(&IncludeColumns);

  %let server= %scan(%sysfunc( getoption(metaserver)),1);
  %let Repository= %sysfunc(compress (%sysfunc( getoption(metarepository)),'"'));
  %put NOTE: Extracting information from Metadata Server: &Server, Repository: &Repository ;
  data &Table ;
   
    length lib_uri tables_uri tab_uri package_uri schema_uri ParentTree_uri Trees_uri $80
      library_name $80 library_engine $20 library_libref $20
      library_isDBMS $1 library_isPreassigned $1 library_Id $25
      source_uri saslib_uri sasvar_uri $80 ParentTree_name $255 Path FolderName $1000
      Name  sasName table_type SchemaName $40 libref $10 
    Updated 8 cUpdated $25 Server $60 Repository $60 Type $30 ID $17
      ;
    retain server "&server" Repository "%unquote(&Repository)";

    call missing(Type, lib_uri, tables_uri, tab_uri, library_name, library_engine, library_libref, library_isDBMS,
                 library_isPreassigned, library_Id, source_uri, saslib_uri, sasvar_uri, Name, sasName, table_type,
                 libref, Updated, cUpdated, ID, package_uri, schema_uri, SchemaName
                 );

    %if "&LibraryName" eq "" %then
      %do;
        nlib=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",1,lib_uri); 
      %end;
    %else 
      %do;
        nlib=metadata_getnobj("omsobj:SASLibrary?@Name = '" || trim("&LibraryName") || "'",1,lib_uri); 
      %end;
    if nlib <= 0 then do;
      msg = sysmsg();
      put 'WARNING: Did not find any libraries in Metadata Server.';
      put msg=;
    end;
    else
      put 'NOTE: Found ' nlib 'libraries in Metadata Server.';

    do nlibs=1 to nlib;
      
        %if "&LibraryName" eq "" %then
        %do;
          lib_obj=metadata_getnobj("omsobj:SASLibrary?@Id contains '.'",nlibs,lib_uri); 
      %end;
      %else 
        %do;
          lib_obj=metadata_getnobj("omsobj:SASLibrary?@Name = '" || trim("&LibraryName") || "'",1,lib_uri); 
      %end;
      
      rc=metadata_getattr(lib_uri,"Id",library_id); 
      rc=metadata_getattr(lib_uri,"Name",library_name); 
      rc=metadata_getattr(lib_uri,"Engine",library_engine); 
      rc=metadata_getattr(lib_uri,"Libref",library_libref);     
      rc=metadata_getattr(lib_uri,"isDBMSLibname",library_isDBMS); 
      rc=metadata_getattr(lib_uri,"isPreassigned",library_isPreAssigned); 
      rc=metadata_getattr(tab_uri,"MetadataUpdated",cUpdated); 
      Updated=input(cUpdated,datetime18.5);

      SchemaName = '';
      ntab=0; 
      if library_isDBMS = '1' then do;
        packages=metadata_getnasn(lib_uri,"UsingPackages",1,package_uri); 
        rc=metadata_getattr(package_uri,"SchemaName",SchemaName); 
        rc=metadata_getnobj(package_uri,1,schema_uri); 
        ntab=metadata_getnasn(schema_uri,"Tables",1,tables_uri); 
        lib_uri = schema_uri;
      end;
      else do;
        ntab=metadata_getnasn(lib_uri,"Tables",1,tables_uri); 
      end;

      
      
      do ntables=1 to ntab;

        rc=metadata_getnasn(lib_uri,"Tables",ntables,tab_uri); 

        rc=metadata_getattr(tab_uri,"id",ID); 
        rc=metadata_getattr(tab_uri,"Name",Name); 
        rc=metadata_getattr(tab_uri,"SASTableName",sasName); 
        rc=metadata_getattr(tab_uri,"MemberType",table_type);     
        rc=metadata_getnasn(tab_uri,"TablePackage",1,saslib_uri); 
        rc=metadata_getattr(saslib_uri,"Libref",libref); 
        rc=metadata_getattr(tab_uri,"MetadataUpdated",cUpdated); 
        Updated=input(cUpdated,datetime18.5);

        * ResponsibleParty;
        length resp_uri $80 Responsible $50;
        call missing(resp_uri, Responsible);
        rc=metadata_getnasn(tab_uri,"ResponsibleParties",1,resp_uri);
        if rc > 0 then do;
          rc=metadata_getattr(resp_uri,"NAME",Responsible); 
        end;

        /* Generate Path */
        call missing(ParentTree_uri,ParentTree_name,FolderName);
        rc=metadata_getnasn(tab_uri,"Trees",1,Trees_uri);
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

    %if %str(&IncludeColumns) = %str(YES) %then
      %do;
        length columnID $17 varname $40 ColumnUpdated 8 length $4 coltype $1 collabel $100 colformat colinformat $40;
        format ColumnUpdated datetime. ;
        call missing(varname, length, columnID, coltype, ColumnUpdated, collabel, colformat, colinformat);
        nvars=metadata_getnasn(tab_uri,"Columns",1,sasvar_uri); 
        do ncolumns=1 to nvars;
          rc=metadata_getnasn(tab_uri,"Columns",ncolumns,sasvar_uri); 
          rc=metadata_getattr(sasvar_uri,"SASColumnName",varname);     
          rc=metadata_getattr(sasvar_uri,"SASColumnLength",length); 
          rc=metadata_getattr(sasvar_uri,"SASColumnType",coltype);     
           rc=metadata_getattr(sasvar_uri,"Desc",collabel);     
          rc=metadata_getattr(sasvar_uri,"SASFormat",colformat);     
          rc=metadata_getattr(sasvar_uri,"SASInformat",colinformat);     
          rc=metadata_getattr(sasvar_uri,"ID",columnID);     
          rc=metadata_getattr(tab_uri,"MetadataUpdated",cUpdated); 
          ColumnUpdated=input(cUpdated,datetime18.5);
          output;
        end;
      drop ncolumns nvars ;
    %end;
    %else %do;
      output;
    %end;
      end;
    end;
    drop lib_uri tables_uri nlibs ntables rc nlib lib_obj saslib_uri sasvar_uri package_uri schema_uri tab_uri resp_uri
       ntab source_uri library_id cUpdated Trees_uri ParentTree_uri ParentTree_Name parentRc FolderName packages;
    format Updated datetime. ;
  run;
  proc sort data=&Table ;
    by Path Name ;
  run;
%options_reset(options=linesize mlogic mprint notes pagesize symbolgen, options_id=sys_check_permissions, put=N);
%mend;
