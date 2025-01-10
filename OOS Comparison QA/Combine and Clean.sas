


/* Create a list of datasets starting with "BIRTH_" */
proc sql noprint;
    select memname into :dataset_list separated by ' '
    from dictionary.tables
    where libname = 'WORK' and upcase(memname) like 'BIRTH_%';
quit;

/* Combine all datasets, filters based on year */
data birth_combined;
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
