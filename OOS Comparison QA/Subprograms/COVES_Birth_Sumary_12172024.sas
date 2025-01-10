


/*  Data pull for comparison report  */

data birtha;
	set birth.birth&yr (keep=certnum DOB facstate resstatename);
		where facstate NE 'Colorado';
run; 


proc sort data=birtha;
	by certnum;
run;

data birthb;
	set birth.admin&yr;
run; 

proc sort data = birthb;
	by certnum;
run;

data birthc;
	merge birtha (in=a)
		birthb;
	by certnum;

	if a;

	if resstatename EQ 'Colorado' and facstate NE 'Colorado';
run; 


proc sort data = birthc;
	by childsid;
run;

data one;
	set coves.birthchild (keep = nchildsid cRecordType);

	where cRecordType EQ '3'; *filters for out of state births;
	childsid = put(nchildsid, 9.);
run;

proc sort data = one;
	by childsid;
run;

data two;
	merge birthc (in=a)
		one;
	by childsid;

	if a;

	if RecordType EQ '3';
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
	retain facstate certnum DOB oos_SFN void;
	set two;
	keep facstate certnum DOB oos_SFN void;
run;

***************************************/
options nocenter;
ods listing close;
ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE\COMPARE_EDR_NCHS\2024\BIRTH" 
	file="(2)COVES_OOS_BIRTH_20&yr..xls" 
	style=htmlblue
	OPTIONS ( Orientation = 'landscape'
	FitToPage = 'yes'
	Pages_FitWidth = '1'
	Pages_FitHeight = '100'
	Zoom = '100'
	Sheet_Name = "COVES_Detail"
	frozen_headers = 'Yes'
	frozen_rowheaders = '1' 
	EMBEDDED_TITLES = 'Yes'
	);
title "(2)COVES OOS SUMMARY REPORT -- DATE CREATED: &date ";

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




