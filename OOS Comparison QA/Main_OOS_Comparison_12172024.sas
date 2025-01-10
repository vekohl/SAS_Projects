
%let date = %sysfunc(today(),date9.);
libname coves odbc dsn=coves schema=dbo;
libname birth 'w:\birth\sas';
run;

/* Define the year for the filenames */
%let yr = 24;

/* Define the folder path for NCHS Reports*/
%let folder_path = V:\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\OOS-NCHS\20&yr.;

/* Define the folder for subprograms */
filename jobs "V:\VITAL RECORDS\Program Support\RDI Unit\Statistical Analyst\SAS_Programs\Quality Assurance Reports\OOS Comparison QA\Subprograms"; 



/* Run NCHS Birth Summary Report */
%include jobs(NCHS_Birth_Summary_12172024);


/* Run COVES Birth Summary Report */
%include jobs(COVES_Birth_Summary_12172024);


/* Run NCHS Birth Summary Report */
%include jobs(Comparison_Report_12172024);


/*delete all work files*/
proc datasets library=WORK kill;
run;























/*** Creates the OOS Deaths Summary and Comparison reports based on NCHS monthly reporting*/
%let yr = 24;

%*Creates a list of all files in the source directory with the specified extension (EXT);
%macro list_files(dir,ext);
	%local filrf rc did memcnt name i;
	%let rc=%sysfunc(filename(filrf,&dir));
	%let did=%sysfunc(dopen(&filrf));

	%if &did eq 0 %then
		%do;
			%put Directory &dir cannot be open or does not exist;

			%return;
		%end;

	%do i = 1 %to %sysfunc(dnum(&did));
		%let name=%qsysfunc(dread(&did,&i));

		%if %qupcase(%qscan(&name,-1,.)) = %upcase(&ext) %then
			%do;
				%put &dir\&name;
				%let file_name =  %qscan(&name,1,.);
				%put &file_name;

				data _tmp;
					length dir $512 name $100;
					dir=symget("dir");
					name=symget("name");
					path = catx('\',dir,name);
					the_name = substr(name,1,find(name,'.')-1);
				run;

				proc append base=list data=_tmp force;
				run;

				quit;

				proc sql;
					drop table _tmp;
				quit;

			%end;
		%else %if %qscan(&name,2,.) = %then
			%do;
				%list_files(&dir\&name,&ext)
			%end;
	%end;

	%let rc=%sysfunc(dclose(&did));
	%let rc=%sysfunc(filename(filrf));
%mend list_files;

%*Macro to import a single file, using the path, filename and an output dataset name must be specified;
%macro import_file(path, file_name, dataset_name );

	proc import 
		datafile="&path.\&file_name."
		out=&dataset_name replace;
		range="Sheet4$";
		getnames=yes;
		mixed=no;
		scantext=yes;
		usedate=yes;
		scantime=yes;
	run;

%mend;

*Create the list of files, in this case all XLS files;
%list_files(V:\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\OOS-NCHS\20&yr, xls );

%*Call macro once for each entry in the list table created from the %list_files() macro;
data _null_;
	set list;
	string = catt('%import_file(', dir, ', ',  name,', ', catt('test', put(_n_, z2.)), ');');
	call execute (string);
run;

data test;
	set test:;

	if F4 EQ "20&yr";
	keep F4 F6 F7 F8 F10 F11 F12;
run;

DATA prep (drop=F4 F6 F7 F8 F10 F11 F12);
	set test;
	DataYear=F4;
	StateOfDeath=F6;
	CertNum=cats(":",F7);
	StateofResidence=F8;
	CountyOfResidence=F10;
	DateofDeath=F11;
	InfantDeath=F12;

	if StateofDeath = 'NEW YORK CITY' then
		StateofDeath = 'NEW YORK';
run;

proc sort data = prep nodupkey;
	by DataYear StateOfDeath CertNum;
run;

/***************************************/
options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE" 
	file="(1)NCHS_OOS_DEATHS_SUMMARY_20&yr..xls" 
	style=htmlblue
	OPTIONS ( Orientation = 'landscape'
	FitToPage = 'yes'
	Pages_FitWidth = '1'
	Pages_FitHeight = '100'
	Zoom = '100'
	Sheet_Name = "NCHS_Detail"
	frozen_headers = 'Yes'
	frozen_rowheaders = '1'
	EMBEDDED_TITLES = 'Yes'
	Row_Heights = '0,12,0,0,0,0,0'
	);
title "(1)NCHS OOS DEATHS SUMMARY -- DATE CREATED: &date ";

proc print data = prep split = '*' label n noobs;
	id DataYear;
	var StateOfDeath 
		CertNum
		StateOfResidence 
		CountyOfResidence 
		DateofDeath 
		InfantDeath
		/style(data)={cellwidth=100pt};
run;

ods tagsets.excelxp options(sheet_name="Summary");

proc freq data = prep;
	tables StateofDeath/missing norow nocol nopercent;
run;

quit;

ods tagsets.ExcelXP close;
ods listing;
libname coves odbc dsn=coves schema=dbo;

data chk;
	set coves.decedent 
		(keep = ndecedentid cssn cdecedentfirstname cdecedentlastname cPlaceOfDeathStateName crecordtype crecordtypedesc cdateofdeath);
	SSN = compress(cssn,'-');
	DOD = input(compress(cDateOfDeath,'/'),yymmdd8.);
	format DOD MMDDYY10.;
	YEAR = YEAR(DOD);

	if YEAR = 20&yr;
	deathstate = upcase(cPlaceofdeathStateName);

	if deathstate NE 'COLORADO';
run;

data chk2;
	set coves.deathgeneral 
		(keep = ndecedentid cstatefilenumber coutofstateSFN);
run;

proc sort data = chk2;
	by ndecedentid;
run;

data chk3;
	merge chk (in=a)
		chk2;
	by ndecedentid;

	if a;
	SFN = cats(':',cstatefilenumber);

	*if SFN EQ ':' and coutofstateSFN NE ' ' then
		do;
			*   SFN = cats(':',coutofstateSFN);
			*end;
run;

data ddata;
	set death.death&yr (keep=ndecedentid residestate);

proc sort data = ddata;
	by ndecedentid;
run;

data final;
	retain deathstate dod OOS_CERT SFN;
	merge chk3 (in=a)
		ddata;
	by ndecedentid;

	if a;

	if residestate IN ("COLORADO","CO"," ");

	*if deathstate NE ' ';
	OOS_CERT = cats(':',coutofstateSFN);

	if OOS_CERT EQ ":" and deathstate EQ ' ' then
		delete;
	keep deathstate dod OOS_CERT SFN residestate;
run;

proc sort data = final;
	by deathstate oos_cert;
run;

/***************************************/
options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE" 
	file="(2)COVES_OOS_DEATHS_SUMMARY_20&yr..xls" 
	style=htmlblue
	OPTIONS ( Orientation = 'landscape'
	FitToPage = 'yes'
	Pages_FitWidth = '1'
	Pages_FitHeight = '100'
	Zoom = '100'
	Sheet_Name = "Detail"
	frozen_headers = 'Yes'
	frozen_rowheaders = '1'
	sheet_interval = "Proc"
	EMBEDDED_TITLES = 'Yes'
	);
title "(2)COVES OOS DEATHS SUMMARY -- DATE CREATED: &date ";

proc print data = final split = '*' label n noobs;
	id DeathState;
	var DoD 
		OOS_CERT
		SFN
		/style(data)={cellwidth=100pt};
	label deathstate="State of Death"
		dod = "Date of Death";
run;

quit;

ods tagsets.excelxp options(sheet_name="Summary");

proc freq data = final;
	tables DeathState/missing;
run;

ods tagsets.ExcelXP close;
ods listing;

data one;
	set final (keep=oos_cert deathstate);
	length stateofdeath $20;
	stateofdeath = deathstate;
	certnum = oos_cert;
	drop deathstate oos_cert;

	if stateofdeath EQ "DISTRICT OF COLUMBIA" then
		stateofdeath = "DISTRICT OF CO";

	if stateofdeath EQ "WV" then
		stateofdeath = "WEST VIRGINIA";

	*if deathstate EQ ' ' or certnum EQ ':' then delete;
	if certnum EQ ':' then
		delete;
run;

proc sort data = one;
	by stateofdeath certnum;
run;

proc sort data = prep nodupkey;
	by stateofdeath certnum;
run;

data mrg;
	merge one (in=a)
		prep (in=b);
	by stateofdeath certnum;

	if (b and not a) or (a and not b and stateofdeath EQ ' ') then
		output;
run;

***************************************/
options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE" 
	file="(3)NCHS_OOS_DEATHS_COMPARE_20&yr..xls" 
	style=htmlblue
	OPTIONS ( Orientation = 'landscape'
	FitToPage = 'yes'
	Pages_FitWidth = '1'
	Pages_FitHeight = '100'
	Zoom = '100'
	Sheet_Name = "Compare_Detail"
	frozen_headers = 'Yes' 
	frozen_rowheaders = '1' 
	EMBEDDED_TITLES = 'Yes'
	);
title "(3)NCHS/COVES DEATHS COMPARISON REPORT -- DATE CREATED: &date ";

proc print data = mrg split = '*' label n noobs;
	id DataYear;
run;

quit;

ods tagsets.ExcelXP close;
ods listing;

/*delete all work files*/
proc datasets library=WORK kill;
run;

quit;

output:
V:\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE\COMPARE_EDR_NCHS\20&yr\BIRTH
	output: V:\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE\COMPARE_EDR_NCHS\20&yr\BIRTH

	NCHS Reports V:\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\OOS -NCHS\20&yr

	/*** Creates the OOS Births Summary and Comparison reports based on NCHS monthly reporting*/
%let yr = 24;

%*Creates a list of all files in the source directory with the specified extension (EXT);
%macro list_files(dir,ext);
	%local filrf rc did memcnt name i;
	%let rc=%sysfunc(filename(filrf,&dir));
	%let did=%sysfunc(dopen(&filrf));

	%if &did eq 0 %then
		%do;
			%put Directory &dir cannot be open or does not exist;

			%return;
		%end;

	%do i = 1 %to %sysfunc(dnum(&did));
		%let name=%qsysfunc(dread(&did,&i));

		%if %qupcase(%qscan(&name,-1,.)) = %upcase(&ext) %then
			%do;
				%put &dir\&name;
				%let file_name =  %qscan(&name,1,.);
				%put &file_name;

				data _tmp;
					length dir $512 name $100;
					dir=symget("dir");
					name=symget("name");
					path = catx('\',dir,name);
					the_name = substr(name,1,find(name,'.')-1);
				run;

				proc append base=list data=_tmp force;
				run;

				quit;

				proc sql;
					drop table _tmp;
				quit;

			%end;
		%else %if %qscan(&name,2,.) = %then
			%do;
				%list_files(&dir\&name,&ext)
			%end;
	%end;

	%let rc=%sysfunc(dclose(&did));
	%let rc=%sysfunc(filename(filrf));
%mend list_files;

%*Macro to import a single file, using the path, filename and an output dataset name must be specified;
%macro import_file(path, file_name, dataset_name );

	proc import 
		datafile="&path.\&file_name."
		out=&dataset_name replace;
		range="Sheet2$";
		getnames=yes;
		mixed=no;
		scantext=yes;
		usedate=yes;
		scantime=yes;
	run;

%mend;

*Create the list of files, in this case all XLS files;
%list_files(V:\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\OOS-NCHS\2024, xls);

%*Call macro once for each entry in the list table created from the %list_files() macro;
data _null_;
	set list;
	string = catt('%import_file(', dir, ', ',  name,', ', catt('test', put(_n_, z2.)), ');');
	call execute (string);
run;

data test;
	set test:;

	if F4 EQ "20&yr";
	keep F4 F6 F7 F8 F10 F11 F12;
run;

DATA prep (drop=F4 F6 F7 F8 F10 F11 F12);
	set test;
	DataYear=F4;
	StateOfBirth=F6;
	CertNum=cats(":",F7);
	StateofResidence='COLORADO';
	CountyOfResidence=F10;
	DateofBirth=F11;

	if F7 EQ 'NEW YORK CITY' then
		StateOfBirth = 'NEW YORK';
run;

proc sort data = prep nodupkey;
	by DataYear StateOfBirth CertNum;
run;

/***************************************/
options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE" 
	file="(1)NCHS_OOS_BIRTH_SUMMARY_20&yr..xls" 
	style=htmlblue
	OPTIONS ( Orientation = 'landscape'
	FitToPage = 'yes'
	Pages_FitWidth = '1'
	Pages_FitHeight = '100'
	Zoom = '100'
	Sheet_Name = "NCHS_Detail"
	frozen_headers = 'Yes'
	frozen_rowheaders = '1'
	EMBEDDED_TITLES = 'Yes'
	Row_Heights = '0,12,0,0,0,0,0'
	);
title "(1)NCHS OOS BIRTH SUMMARY -- DATE CREATED: &date ";

proc print data = prep split = '*' label n noobs;
	id DataYear;
	var StateOfBirth 
		CertNum
		StateOfResidence 
		CountyOfResidence 
		DateofBirth 
		/style(data)={cellwidth=100pt};
run;

ods tagsets.excelxp options(sheet_name="Summary");

proc freq data = prep;
	tables StateofBirth/missing norow nocol nopercent;
run;

quit;

ods tagsets.ExcelXP close;
ods listing;

data birtha;
	set birth.birth&yr (keep=certnum DOB facstate resstatename);

proc sort data=birtha;
	by certnum;
run;

data birthb;
	set birth.admin&yr;

proc sort data = birthb;
	by certnum;
run;

data birthc;
	merge birtha (in=a)
		birthb;
	by certnum;

	if a;

	if resstatename EQ 'Colorado' and facstate NE 'Colorado';

proc sort data = birthc;
	by childsid;
run;

data one;
	set covis_ro.birthgeneral (keep = cchildsid cChildsMedRec cInhRecordType cOldOOSSFN cvoid);
	where cInhRecordType EQ 'RecordType|5';
	childsid = cchildsid;
run;

proc sort data = one;
	by childsid;
run;

data two;
	merge birthc (in=a)
		one;
	by childsid;

	if a;

	if RecordType EQ '5';
	length oos_SFN $8;
	oos_SFN = cats(':',cOldOOSSFN);

	if oos_SFN EQ ':' and cChildsMedRec NE ' ' then
		do;
			oos_SFN = cats(':',cChildsMedRec);
		end;
run;

proc sort data = two;
	by facstate certnum;
run;

data out_excel;
	retain facstate certnum DOB oos_SFN cvoid;
	set two;
	keep facstate certnum DOB oos_SFN cvoid;
run;

***************************************/
options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE" 
	file="(2)COVIS_OOS_BIRTH_20&yr..xls" 
	style=htmlblue
	OPTIONS ( Orientation = 'landscape'
	FitToPage = 'yes'
	Pages_FitWidth = '1'
	Pages_FitHeight = '100'
	Zoom = '100'
	Sheet_Name = "COVIS_Detail"
	frozen_headers = 'Yes'
	frozen_rowheaders = '1' 
	EMBEDDED_TITLES = 'Yes'
	);
title "(2)COVIS OOS SUMMARY REPORT -- DATE CREATED: &date ";

proc print data = out_excel split = '*' label n noobs;
	id FacState;
	label facstate='StateofBirth'
		certnum='CertNum';
run;

ods tagsets.excelxp options(sheet_name="Summary");

proc freq data = out_excel;
	tables FacState/missing norow nocol nopercent;
run;

quit;

ods tagsets.ExcelXP close;
ods listing;

data one;
	set out_excel(keep=certnum DOB oos_SFN facstate);

	if facstate = 'District of Columbia' then
		facstate ='District of Co';
	facstate=upcase(facstate);

proc sort data = one;
	by facstate oos_SFN;
run;

data two;
	set prep;
	length oos_SFN $8 facstate $50;
	oos_SFN = certnum;
	drop certnum;
	facstate=stateofbirth;

proc sort data = two;
	by facstate oos_SFN;
run;

data mrg;
	retain DataYear StateOfBirth oos_SFN StateofResidence CountyOfResidence DateofBirth;
	merge one (in=a)
		two (in=b);
	by facstate oos_SFN;
	drop DOB facstate certnum;

	if b and not a then
		output;
run;

data mrg2;
	retain certnum DOB oos_SFN facstate;
	merge one (in=a)
		two (in=b);
	by facstate oos_SFN;
	drop DataYear StateOfBirth StateofResidence CountyOfResidence DateofBirth;

	if a and not b then
		output;
run;

***************************************/
options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE" 
	file="(3)NCHS_OOS_BIRTH_COMPARE_20&yr..xls" 
	style=htmlblue
	OPTIONS ( Orientation = 'landscape'
	FitToPage = 'yes'
	Pages_FitWidth = '1'
	Pages_FitHeight = '100'
	Zoom = '100'
	Sheet_Name = "Reported By NCHS NOT In COVIS"
	frozen_headers = 'Yes'
	frozen_rowheaders = '1' 
	EMBEDDED_TITLES = 'Yes'
	);
title "(3)NCHS/COVIS COMPARISON REPORT -- DATE CREATED: &date ";

proc print data = mrg split = '*' label n noobs;
	id DataYear;
run;

ods tagsets.excelxp options(sheet_name="In COVIS NOT NCHS");

proc print data = mrg2 split = '*' label n noobs;
	id Facstate;
	label FacState = 'StateofBirth'
		certnum = 'CertNum';
run;

quit;

ods tagsets.ExcelXP close;
ods listing;

/*delete all work files*/
proc datasets library=WORK kill;
run;

quit;

data _null_;
	datetime = datetime();
	format datetime datetime16.;
	call symputx('datetime',put(datetime,datetime16.));
run;

options emailsys="smtp" emailhost="10.48.200.202" emailport=25;
filename mail email 
	to=('ash.sethi@state.co.us')
	cc=('kirk.bol@state.co.us' 'steve.boylls@state.co.us' 'tami.rodriguez@state.co.us' 'grahame.dryden@state.co.us')
	from='kirk.bol@state.co.us' 
	subject="Inter-Jurisdictional Exchange Birth OOS Process (20&yr) Has Completed &datetime";

DATA _NULL_;
	FILE mail;
	PUT @1 "IJE BIRTH OOS Reports Created - Please refer to VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE";
RUN;
