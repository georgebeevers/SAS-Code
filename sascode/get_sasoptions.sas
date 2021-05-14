proc printto log="C:\temp\log.log" new ;
run;
/*options nonotes nosource;*/
proc options value;
run;
proc printto;
run;
/*options notes source;*/
data myoptions ;
	length string  $1000. optname $100 value howset how $1000. ;
	infile "C:\temp\log.log" dsd flowover;
/*	currnum=0;*/
	input string $ ;
	retain optname value howset how;
/*	delete system rows*/
	if find(_infile_,"The SAS System") then do ;
	delete;
	end;
	if find(_infile_,"Option Value Information For SAS Option") then
		do;
			optname=scan(_infile_,-1);output;
		end;
	if find(_infile_,"How option value set:") then do;
	how=scan(_infile_,-1,":",'QR');
	end;
	if find(_infile_,"Value:") then do;
	value=tranwrd(_infile_,"Value:","");
	end;
	if find(_infile_,"Config file name") then
		do; 
/*currnum=0;*/
/*			current=currnum+_n_;*/
/*			next=_n_+1;*/
/*			move on one line to get the value*/
			input pointer=+1;
			howset=compress(_infile_);
/*			output;*/
		end;
		if how ne "Config File" then howset =" ";
/*		output;*/
		drop string pointer ;
run;

proc sort data=myoptions nodupkey;
by optname value;
run;

proc options option=MEMSIZE value;
run;