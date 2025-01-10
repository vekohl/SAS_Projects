

/* Create a list of files in the folder */
filename dirlist pipe "dir ""&folder_path.\CO&yr.*.xlsx"" /b";

data file_list;
    infile dirlist truncover;
    input filename $100.;
    month = scan(scan(filename, 2, '_'), 1, '.');
    output;
run;

filename dirlist clear;

/* Import files  */
%macro import_files_from_list;

    /* Create a macro variable for all filenames */
    proc sql noprint;
        select filename into :filelist separated by '|' from file_list;
    quit;

    /* Loop through each filename and import */
    %let count = %sysfunc(countw(&filelist, |));

    %do i = 1 %to &count;
        %let current_file = %scan(&filelist, &i, |);
        %let current_month = %substr(&current_file, 5, 2); 

        proc import datafile="&folder_path.\&current_file"
            out=birth_&current_month replace;
            range="Sheet2$";
            getnames=yes;
            mixed=no;
            scantext=yes;
            usedate=yes;
            scantime=yes;
        run;

    %end;

%mend;

%import_files_from_list;



/* Create a list of datasets starting with "BIRTH_" */
proc sql noprint;
    select memname into :dataset_list separated by ' '
    from dictionary.tables
    where libname = 'WORK' and upcase(memname) like 'BIRTH_%';
quit;

/* Combine all datasets, filters based on year */
data NCHS_combined;
    length F3 $8 F5 $50 F6 $15 F7 $50;
    keep F3 F5 F6 F7; 
    drop F1 F2 F4 F8;

    /* Assign meaningful labels */
    label F3 = "DataYear" F5 = "StateOfBirth" F6 = "CertNo"  F7 = "StateOfResidence";

    /* Set formats for consistent output */
    format F3 $CHAR12. F5 $CHAR14. F6 $CHAR11. F7 $CHAR18.;
    informat F3 CHAR12. F5 $CHAR14. F6 $CHAR11. F7 $CHAR18.;

    /* Dynamically set all datasets starting with "birth_" */
    set &dataset_list.;

    /* Ensure CertNo is 6 digits with leading zeros */
    if length(F6) < 6 then F6 = put(input(F6, 6.), z6.);

    /* Filter data for the correct year */
    if F3 = "20&yr";
run;


/* Prepare Birth Data for Reporting */
data birthNCHS; 
	set NCHS_combined;
	DataYear = F3;
	StateOfBirth = F5;
	CertNum = F6;
	StateOfResidence = F7;
run;

/* Remove duplicates */
proc sort data=birthNCHS nodupkey;
	by DataYear StateOfBirth CertNum;
run;

	options nocenter;
	ods listing close;
	ods tagsets.ExcelXP path="\\dphe.local\cheis\programs\HSVR\VITAL RECORDS\Program Support\RDI Unit\Data Management\Registration QA\STEVE\COMPARE_EDR_NCHS\2024\BIRTH" 
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

proc print data = birthNCHS split = '*' label n noobs;
	id DataYear;
	var StateOfBirth 
		CertNum
		StateOfResidence 
		/style(data)={cellwidth=100pt};
run;

ods tagsets.excelxp options(sheet_name="Summary");

proc freq data = birthNCHS;
	tables StateofBirth/missing norow nocol nopercent;
run;

quit;

ods tagsets.ExcelXP close;
ods listing;

