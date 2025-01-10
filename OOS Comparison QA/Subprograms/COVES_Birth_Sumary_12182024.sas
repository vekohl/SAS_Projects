


/*  Data pull from COVES */

data birth&yr;
	set birth.birth&yr;
		where facstate NE 'Colorado' and resstatename EQ 'Colorado';
run; 

data birthadmin; 
	set birth.admin&yr; 
	cChildsId = put(mod(childsid, 1000000), z6.);
	where RecordType EQ '3';
run; 

proc sql; 
	create table birthsas as	
		select	
			a.certnum, 
			a.DOB,
			a.facstate,
			a.resstatename,
			b.cChildsID
		from	
			birth&yr as a
		left join
			birthadmin as b
		on
			a.certnum = b.certnum;
quit;  

data birthoosSFN;
	set coves.birthchild (keep = cRecordType nchildsid cChildsMedRec cOutOfStateSFN cFacilityStateName);
	cChildsId = put(mod(nchildsid, 1000000), z6.);
	where cRecordType EQ '3'; 
run;


proc sql; 
	create table birthmerge as	
		select	
			a.certnum, 
			a.DOB,
			a.facstate,
			a.resstatename,
			b.*
		from	
			birthsas as a
		left join
			birthoosSFN as b
		on
			a.cChildsID = b.cChildsId;
quit; 

data birthcoves;
	set birthmerge;
	length oos_SFN $8;
	oos_SFN = cats(':',cOutOfStateSFN);

	if oos_SFN EQ ':' and cChildsMedRec NE ' ' then
		do;
			oos_SFN = cats(':',cChildsMedRec);
		end;
run;

data out_excel;
	retain facstate certnum DOB oos_SFN;
	set birthcoves;
	keep facstate certnum DOB oos_SFN;
run;

proc sort data=out_excel; 
by facstate; 
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




