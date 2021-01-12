* --------------------------------------------------------------------;
* Catalog      : macros                                               ;
* Program Name : metadata_transassoc.sas                              ;
*                                                                     ;
* --------------------------------------------------------------------;
* Function:                                                           ;
* Use the metadata_getnasn function to gather association             ;
* information.                                                        ;
*                                                                     ;
* Parameters:                                                         ;
*   omsobj  - Specify the full OMSOBJ / URI reference for the         ;
*     metadata object for which you want to get the full tree         ;
*     e.g. OMSOBJ:JOB\AB12CD34.EF56GH78                               ;
*     Alternatively, specify a dataset with a variable containing a   ;
*     list of OMSOBJ references                                       ;
*   uri     - The column which holds the OMSOBJ / URIs when a dataset ;
*     is used (default "uri").                                        ;
*   assoc   - Specify the association for which you want to retrieve  ;
*     information. When blank it will extract all associations.       ;
*   attr    - Specify the attribute for which you want to retrieve    ;
*     information. When blank it will extract all attributes.         ;
*   out_ref - The <library>.<dataset> that output is stored in when   ;
*     the "DATA" type is used (default "work._transassoc_output_").   ;
*   type    - Whether the output is directed to DATA, the LOG or the  ;
*     OUTPUT window (default "DATA").                                 ;
*   put     - Y/N flag to put information to the log (default "N").   ;
* --------------------------------------------------------------------;
* Version Date      Author of    Change  Brief Description of         ;
* Number  Issued    Modification Req No. Modification                 ;
* ======= ========= ============ ======= =============================;
* 1.0.0   26MAR2018 L Mitchell   N/A     Created                      ;
* --------------------------------------------------------------------;
 
%macro metadata_transassoc(omsobj=, uri=uri, assoc=, attr=, out_ref=work._transassoc_output_, type=DATA, put=N) / mindelimiter=','
des = 'Use the metadata_getnasn function to gather association information.';
 
  options minoperator;
 
  %*** Set macro variables to be local to avoid conflicts. ;
  %local exe_cmd uri_count;
 
  %*** Give execute command a default value of 0. ;
  %let exe_cmd = 0;
 
  %*** If the value of omsobj is a datset that exists then do ... ;
  %if %sysfunc(exist(%superq(omsobj))) %then %do;
 
    %*** If the put flag is used, then put information to the log. ;
    %if %sysfunc(upcase(%superq(put))) = Y %then %do;
      %put ;
      %put INFO: A dataset has been detected as input (%superq(omsobj)). ;
    %end;
 
    %*** Get the contents of the dataset that we know exists. ;
    proc contents noprint
      data = %superq(omsobj)
      out = work.contents;
    run;
 
    %*** Count how many variables match the URI macro variable (it will be either 0 or 1). ;
    proc sql noprint;
      select count(*) 
      into :uri_count separated by ''
      from work.contents
      where upcase(name) = upcase("%superq(uri)")
    ;quit;
 
    %*** Delete the temp table(s). ;
    proc datasets lib=work nolist;
      delete 
        contents
        ;
      run;
    quit;
 
    %*** If the URI count is equal to 1 then set execute command and define the input. ;
    %if &uri_count. = 1 %then %do;
 
      %*** If the put flag is used, then put information to the log. ;
      %if %sysfunc(upcase(%superq(put))) = Y %then %do;
        %put INFO: The variable %superq(uri) has been detected in the dataset (%superq(omsobj)). ;
        %put ;
      %end;
 
      %*** Set execute command. ;
      %let exe_cmd = 1;
 
      %*** Create a dataset with the distinct OMSOBJ stored in the URI variable. ;
      proc sql;
      create table work._uri_input_ as 
        select distinct 
          %superq(uri) as uri length=64
        from %superq(omsobj)
      ;quit;
 
    %end;
    %*** If the URI count is equal to 0 then put an (er)ror to the log. ;
    %else %do;
      %put %str(ER)ROR: The variable %superq(uri) has NOT been detected in the dataset (%superq(omsobj)). ;
    %end;
 
  %end;
  %*** ... otherwise check if the value begins with OMSOBJ: ... ;
  %else %if %sysfunc(substr(%sysfunc(upcase(%superq(omsobj))),1,%length(OMSOBJ:))) = OMSOBJ: %then %do;
 
    %*** If the put flag is used, then put information to the log. ;
    %if %sysfunc(upcase(%superq(put))) = Y %then %do;
      %put ;
      %put INFO: An Ontology Management Studio Object has been detected as input (%superq(omsobj)). ;
      %put ;
    %end;
 
    %*** Set execute command. ;
    %let exe_cmd = 1;
 
    %*** Create a single row dataset with the OMSOBJ stored in the URI variable. ;
    data work._uri_input_;
      length 
        uri $64.
        ;
      uri = "%superq(omsobj)";
    run;
 
  %end;
  %*** ... otherwise put an (er)ror to the log. ;
  %else %do;
    %put %str(ER)ROR: An invalid value has been detected as input (%superq(omsobj)). ;
  %end;
 
  %*** Only execute the next section when execute command is set equal to 1. ;
  %if &exe_cmd. = 1 %then %do;
 
    %*** If any of the correct types are passed then perform the metadata call. ;
    %if %sysfunc(upcase(%superq(type))) in DATA, LOG, OUTPUT %then %do;
 
      %*** If there is no assoc value populated then perform a general metadata association query. ;
      %if %sysevalf(%superq(assoc)=,boolean) = 1 %then %do;
 
        data work._transassoc_output_1a_ (keep=uri assoc assoc_uri);
          set work._uri_input_;
          length
            assoc $32
            assoc_uri $64
            ;
          rc1=1;
          i=1;
          %*** Loop until rc1 is 0 indicating there is no m+1 association type. ;
          do until(rc1<=0);
            %*** Walk through all possible associations types for the object. ;
            rc1=metadata_getnasl(uri,i,assoc);
            rc2=1;
            j=1;
            %*** Loop until rc2 is 0 indicating there is no j+1 associated object for the current association type. ;
            do until(rc2<=0);
              rc2=metadata_getnasn(uri,assoc,j,assoc_uri);
              if (rc2>0) then do;
                output;
              end;
              j=j+1;
            end;
            i=i+1;
          end;
        run;
 
      %end;
      %*** If there is an assoc value populated then perform a specific metadata association query. ;
      %else %do;
 
        data work._transassoc_output_1a_ (keep=uri assoc assoc_uri);
          set work._uri_input_;
          length
            assoc $32
            assoc_uri $64
            ;
          assoc = "%superq(assoc)";
          rc1=1;
          i=1;
          %*** Loop until rc1 is 0 indicating there is no i+1 associated object for the association type. ;
          do until(rc1<=0);
            rc1=metadata_getnasn(uri,assoc,i,assoc_uri);
            if (rc1>0) then do;
              output;
            end;
            i=i+1;
          end;
        run;
 
      %end;
 
    %end;
 
    %metadata_transattr(omsobj=work._transassoc_output_1a_, uri=assoc_uri, attr=%superq(attr), out_ref=work._transassoc_output_1b_);
 
    proc sql;
    create table work._uri_output_ (drop=temp_uri) as 
      select 
        a.uri,
        a.assoc,
        a.assoc_uri,
        b.*
      from work._transassoc_output_1a_ as a
      inner join work._transassoc_output_1b_ (rename=(uri=temp_uri)) as b
        on a.assoc_uri = b.temp_uri
    ;quit;
 
    %*** Delete the temp table(s). ;
    proc datasets lib=work nolist;
      delete
        _transassoc_output_1a_
        _transassoc_output_1b_
        ;
      run;
    quit;
 
    %*** If the type is DATA then output to the specified output reference. ;
    %if %sysfunc(upcase(%superq(type))) = DATA %then %do;
      data %superq(out_ref);
        set work._uri_output_;
      run;
    %end;
 
    %*** If the type is LOG then print the information to the log. ;
    %else %if %sysfunc(upcase(%superq(type))) = LOG %then %do;
      data _null_;
        set work._uri_output_;
        put (_all_)( = );
      run;
    %end;
 
    %*** Else if the type is OUTPUT then print the information to the results / output window. ;
    %else %if %sysfunc(upcase(%superq(type))) = OUTPUT %then %do;
      proc print
        data = work._uri_output_;
        var _all_;
      run;
    %end;
 
    %*** Otherwise put an (ER)ROR to the log. ;
    %else %do;
      %put %str(ER)ROR: The only valid values for "type" are "DATA", "LOG" and "OUTPUT";
    %end;
 
 %end;
 
  %if %sysfunc(exist(work._uri_input_)) %then %do;
 
    %*** Delete the temp table(s). ;
    proc datasets lib=work nolist;
      delete 
        _uri_input_
        ;
      run;
    quit;
 
  %end;
 
  %if %sysfunc(exist(work._uri_output_)) %then %do;
 
    %*** Delete the temp table(s). ;
    proc datasets lib=work nolist;
      delete 
        _uri_output_
        ;
      run;
    quit;
 
  %end;
 
%mend metadata_transassoc;
