%macro getfilelist(Path=, Table=, TypeFilter=, Recursive=No, DirNumber=0);
  %if %sysfunc(fileexist(&Path)) = 0 %then %do;
    %put WARNING: Path &Path not found.;
  %end;
  %else %do;
    %local notes;
    %let notes=%sysfunc(getoption(notes));
    *option nonotes;
    %let CurrTable = %str(_Files_&DirNumber.);
    %let DirNumber = %eval(&DirNumber. + 1);
    %let current_locale= %sysfunc(getoption(locale)); 
    options locale=en_us; /* Set locale to US in order to read in Created and Updated values correct. */
    %let directory = &path;
    /* List of target columns to keep  */ 
    %let keep = directory memberName FullName name extension entryType created updated filesize;
    %if &sysscp = WIN %then %let sep=\;
    %else %let sep=/;
    filename _F&DirNumber temp;
    data &CurrTable.;
      file _F&DirNumber;
      put "proc append base=&Table data=&CurrTable. force;"
        / "run;"
        / "proc delete data=&CurrTable.;"
        / "run;"
        ;
      length directory $300 memberName $300 fullName $600 filter $100 entryType $10 created updated Filesize 8 name $80 cdate $40;
      format created updated datetime18.5 Filesize commax20.;
      retain directory "&directory";
      rc = filename('dir', "&directory");
      if rc ne 0 then
      do;
        msg = sysmsg();
        putlog "ERROR: unable to open directory &directory, message was: " msg;
        abort;
      end;

      dirID = dopen('dir');
      if dirID = 0 then
      do;
        msg = sysmsg();
        putlog "ERROR: unable to open directory &directory, message was: " msg;
        abort;
      end;

      nMembers = dnum(dirID);
      do i=1 to nMembers;
        memberName = dread(dirID, i);
        fullName = trim(directory) || "&sep" || memberName;

        entryType = 'Unknown';
        rc = filename('entry', fullName);
        fileID = fopen('entry');
        if fileID > 0 then 
        do;
          entryType = 'File';
          %if &sysscp = WIN %then %do;
            Created = input(finfo(fileID,'Create Time'),datetime.);
            Updated = input(finfo(fileID,'Last Modified'),datetime.);
          %end;
          %else %do;
            cdate = finfo(fileID,'Last Modified');
            Created = input( 
                      cats( scan(cdate,3,' '),
                        scan(cdate,2,' '),
                        scan(cdate,5,' '),
                        ':',
                        scan(cdate,4,' ')),
                      datetime.);
            Updated = Created;
          %end;
          Filesize= input(finfo(fileID,'File size (bytes)'),16.);
          close=fclose(fileID);
        end;
        else
        do;
          fileID = dopen('entry');
          if fileID > 0 then 
          do;
            entryType = 'Directory';
            close=dclose(fileID);
            %if %upcase(&Recursive) = YES %then %do;
            put '%GetFileList(Path=' fullName +(-1) ", Table=&Table, TypeFilter=&TypeFilter, Recursive=&Recursive, DirNumber=&DirNumber)" ;
            %end;
          end;
        end;

        extPos = (length(memberName)+1) - index(reverse(trim(memberName)),'.');
        if extPos then /* The file has an extension */
          do;
            name = substr(memberName, 1, extPos-1);
            extension = substr(memberName, extPos+1);
          end;
        else 
          do;
            name = memberName;
            extension = '';
          end;
          if "&TypeFilter" = "" then output;
          else do;
            filterno = 1;
            found = 0;
            filter = "";
            do until(filter = "" or found = 1);
              filter = scan("&TypeFilter", filterno);
              filterno + 1;
              if filter ne "" and upcase(filter) = upcase(extension) then found = 1;
            end;
            if found then output;
          end;
      end;

      rc = dclose(dirID);
      keep &keep;
    run;
    %inc _F&DirNumber;
    filename _F&DirNumber clear;
    options locale=&current_locale; /* Restore locale value */
    option &notes.; /* Restore locale value */
    %put NOTE: Table &Table has been created.;
  %end;
%mend;

/*%put &SYSJOBID;*/