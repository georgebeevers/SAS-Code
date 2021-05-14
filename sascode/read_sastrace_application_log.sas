/*Set the log location and then read in the different message types.*/
/*When the application logging has been set to tracing a number of messages are sent to the log. In this case */
/*96 different messages were sent to the log. We need to obtain these and then use them to split the log up. This */
/*will make it easier to read. There may be more or less and this is why we dynamically check for the message classes*/
%let logloc=C:\Users\sukgeb\AppData\Roaming\SAS\EnterpriseGuide\8\Logs\SEGuide_log.14544_local_drive.txt;
data message_name;
length message last_word $200 ;
/*format dttm datetime20. date date9. time time10.;*/
infile "&logloc." missover dlm=" " ;
input ;
retain message;
message=scan(_infile_,5," ","QR");
   call scan(message, -1, pos, length);
   last_word=substr(message,pos,length);
   if countw(message,".") >2 then output;
run;
proc sort data=message_name nodupkey;
by message;
run;
/*Create macro variables for the loop*/
proc sql;
select message 
,last_word
into: message_name1 - 
,:short_name1 - 
from message_name;
quit;

%put &message_name1;
%put |&short_name1|;
/*options mprint symbolgen mlogic;*/
/*Loop over the data and extract a table for each message*/
%macro read_egtrace(table=egtrace_all,type=DEBUG,msg_name=);
%do i=1 %to 96;
%let table="&&short_name&i.";
%put &table.;

	data &table. (drop=string start len);
		length string $32767;
		format dttm datetime20. date date9. time time10.;
		infile "&logloc." missover dlm=" ";
		input;

		if find(_infile_,"&&message_name&i.") and find(_infile_,"&type.") then
			do;
				string=_infile_;
				dttm=input(scan(_infile_,1,",","QR"),e8601dt23.3);
				date = datepart(input(scan(_infile_,1,',',"QR"),e8601dt23.3));
				time = timepart(input(scan(_infile_,1,',',"QR"),e8601dt23.3));
				message_type=scan(_infile_,4," ","QR");
				message_sub=scan(_infile_,5," ","QR");
				message=scan(_infile_,5," ","QR");
				start=findw(_infile_,"&type."," ");
				len=lengthn(_infile_);
				message=compress(substr(_infile_,start,len-(start-1)),"&type.");
				output;
			end;
	run;
 %end;

%mend;
%read_egtrace;
/*%read_egtrace(/*table=egtrace_log,*/msg_name=SAS.EC.Directory.Metadata.OMSProvider);*/


