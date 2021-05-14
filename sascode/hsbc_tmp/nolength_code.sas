data temp(keep=make country);
set sashelp.cars;
/*length country $20;*/
if make="Buick" then country='US         ';
else if make="Audi" then country='Germany      ';
else country='Missing';
where make in ("Buick","Audi","BMW");
l=length(country);
put make='L='l;
run;

