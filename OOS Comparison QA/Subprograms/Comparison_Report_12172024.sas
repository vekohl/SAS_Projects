

data coves;
	set birthcoves;

	if facstate = 'District of Columbia' then
		facstate ='District of Co';
	facstate=upcase(facstate);
run; 

pro


data mrg;
	retain DataYear StateOfBirth oos_SFN StateofResidence CountyOfResidence DateofBirth;
	merge coves (in=a)
		birthnchs (in=b);
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
	Sheet_Name = "Reported By NCHS NOT In COVES"
	frozen_headers = 'Yes'
	frozen_rowheaders = '1' 
	EMBEDDED_TITLES = 'Yes'
	);
title "(3)NCHS/COVES COMPARISON REPORT -- DATE CREATED: &date ";

proc print data = mrg split = '*' label n noobs;
	id yr;
run;

ods tagsets.excelxp options(sheet_name="In COVES NOT NCHS");

proc print data = mrg2 split = '*' label n noobs;
	id Facstate;
	label FacState = 'StateofBirth'
		certnum = 'CertNum';
run;

quit;

ods tagsets.ExcelXP close;
ods listing;




