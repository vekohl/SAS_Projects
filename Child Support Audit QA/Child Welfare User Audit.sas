%let qtr=Q4_2023; 

data calc_date; 
 startdate = '01OCT2023'D; 
 enddate = '31DEC2023'D;  
  strtdate=put(startdate,date9.);
  edate=put(enddate,date9.);
   call symput('startdate',trim(left(put(strtdate,$9.))));
   call symput('enddate',trim(left(put(edate,$9.))));
run; 

%put &startdate &enddate &qtr;

proc sql; 
connect to odbc as mycon 
   (datasrc=covis_ro readbuff=1 user=genesisrpt password="wRm79)");

create table cw_audit1 as
select * 
   from connection to mycon
(
 Select g.ncDOBYear as [Year], g.nStateFileNumber as [SFN],
g.cChildsFirstName as [ChildFirstName], g.cChildsMiddleName as [ChildMiddleName], g.cChildsLastName as [ChildLastName],
g.dChildsDateOfBirth as [DOB], g.cMothersFirstName as [MotherFirstName], g.cMothersLastName as [MotherCurrentLastName],
g.cMothersMaidenLastName as [MotherMaidenName], o.cMothersDateofBirth as [MotherDOB], Coalesce(g.cFathersFirstName,'') as [FatherFirstName],
Coalesce(g.cFathersLastName, '') as [FatherLastName], s.cUserID As [UserID], s.cUserLastName as [UserName],
s.cDepartment As [Department], v.dts as [TimeViewed]
From ViewAudit v
Inner Join BirthGeneral g on g.cChildsID = v.cMainID And g.dSealed Is Null
Inner Join BirthOtherGeneral o on o.cChildsID = g.cChildsID and o.nVersionID = g.nVersionID
Inner Join SecurityUser s on s.cUserID = v.cUID
Where v.cuid NOT IN (SELECT cuserid FROM securityuserlocation WHERE cLocationID = '1')      
Order By g.nCDOByear, g.nStateFileNumber
);
 
disconnect from mycon;
quit;

data ck; 
 set cw_audit1;
  if timeviewed GE "&startdate:00:00:00"DT and timeviewed LT "&enddate:00:00:00"DT;
  if substr(department,1,3) EQ 'CW';
  today=today(); format today mmddyy10.;
  DateofBirth = datepart(DOB); format DateofBirth mmddyy10.;
  AgeAtRpt=datdif(DateofBirth, today, 'act/act')/365;
  if AgeAtRpt LT 18 then AgeGrp="Child";
  if AgeAtRpt GE 18 then AgeGrp="Adult";
run;

proc sort data = ck nodupkey dupout = dups; 
by year department SFN; 
run; 
 
proc sort data = ck; by department; run ; 

proc freq data= ck noprint; 
tables department/out = departmentcnt;
run;

proc freq data = ck noprint;
tables AgeGrp/missing nopercent nocol norow out=AgeGrp_cnt; 
run;

data selectdept; 
 set departmentcnt (keep=department count); 
  if count le 3;
  drop count;
run; 
proc sort data = selectdept; by department; run; 

data mrg1; 
 merge ck (in=a)
       selectdept (in=b); 
	    by department; 
		if b then keep = 1;
		if agegrp = 'Adult' then keep = 1;
run; 

proc freq data = mrg1; 
 tables keep ; 
run; 
 
data select_recs;
 set mrg1; 
  where keep NE 1;
run; 

data _NULL_;
	if 0 then set select_recs nobs=n;
	call symputx('nrows',n);
	stop;
run;

%put nobs=&nrows;

proc freq data = select_recs;
tables department/out=freq2;
run; 

proc sort data = select_recs;
by department;
run;

proc surveyselect data = select_recs
n=90 out=samplesizes;
strata department / alloc=prop nosample;
run;

proc surveyselect data = select_recs
method=srs n=samplesizes 
seed=1953 out=sampleStrata;
strata department ;
run;
proc sort data = sampleStrata; by department; run; 

proc freq data = samplestrata;
tables department/out=freq_sample;
run;

data calc_keep; 
 set sampleStrata; 
  by department; 
  if first.department then do; 
   cnt = 0;
  end;
   cnt + 1; 
  *if cnt LE 3 then output;
run; 

proc freq data = calc_keep; 
 tables department/out = freq_sample;
run;

data calc_keep2; 
 set mrg1;
  where keep = 1;
run; 

data final_keep (drop=today DateofBirth AgeAtRpt keep SelectionProb SamplingWeight cnt); 
 set calc_keep2
     calc_keep;
run; 

proc sort data = final_keep nodupkey; 
 by year department SFN; 
run; 

/*ensure all departments are included in the final audit file*/
proc freq data = final_keep;
 tables department/nopercent out=freq_final;
run;

proc sort data = final_keep; 
 by department SFN;
run;

/*check distribution of minor children and adults*/
proc freq data = final_keep;
 tables agegrp; 
run;

data final_keep;
retain Year SFN ChildFirstName ChildMiddleName ChildLastName DOB MotherFirstName MotherCurrentLastName MotherMaidenName
       MotherDOB FatherFirstName FatherLastName UserID UserName Department TimeViewed AgeGrp;
 set final_keep; 
run; 

options mautosource sasautos="&sanref\vsprogs\macros";
%excelout (set=final_keep, file=SteveB\QuarterlyAuditFiles\CW_audit_file_&qtr..xlsx, sheet=&qtr);
