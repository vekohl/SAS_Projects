/* Define the COVES data source (SQL Server connection) */
libname coves odbc dsn= coves;

/* Define audit parameters (date ranges, file output path) */
%let audit_start = '01JAN2024'd; /* Placeholder: start of audit date range */
%let audit_end = '29FEB2024'd;   /* Placeholder: end of audit date range */
%let output_path = 'I:\Datamgt\cowell\App Audit\2024'; /* Placeholder: file output directory */


/* Filter for specific locations */
data filtered_locations;
    set coves.transaction_data; /* Replace with the actual dataset name */

    /* List of locations to include in the audit */
    if LocationName in (
        'Adams', 'Douglas', 'Lincoln', 'San Miguel', 
        'Alamosa/Conejos/Costilla', 'Eagle', 'Logan', 'Sedgwick', 
        /* ... (Include all locations from the list) ... */
        'Yuma/Yuma'
    );
run;
/* Filter transactions based on status, date, and transaction categories */
data filtered_transactions;
    set filtered_locations;

    /* Transaction must be completed */
    if TransactionStatus = 'Completed';

    /* Request must be entered within the audit period */
    if RequestEnteredDate between &audit_start and &audit_end;

    /* Transaction category must start with 'birth', 'death', or 'fetal death' */
    if upcase(substr(TransactionCategory, 1, 5)) in ('BIRTH', 'DEATH') 
        or upcase(substr(TransactionCategory, 1, 11)) = 'FETAL DEATH';
run;
/* Filter for specific transaction types */
data filtered_types;
    set filtered_transactions;

    /* Transaction Types to include */
    if TransactionType in (
        'CO Government Agency', 'Correction', 'Criminal Investigation', 'Genealogy',
        'Heirloom', 'HS Referral', 'Pursuant to Adoption', 'Standard', 'Verification',
        /* ... (Include all transaction types as listed for birth, death, fetal death) ... */
        'Fetal Death Certificate', 'Stillbirth'
    );
run;
/* Randomly sample 8 birth and 8 death/fetal death transactions */
proc surveyselect data=filtered_types
    out=sampled_transactions
    method=srs /* Simple random sampling */
    sampsize=(8 8) /* 8 birth and 8 death/fetal death transactions */
    seed=12345; /* For reproducibility */
    strata TransactionCategory; /* Ensure sampling across categories */
run;
/* Output the sampled data to the specified directory */
proc export data=sampled_transactions
    outfile="&output_path./Audit_Sample_&sysdate..xlsx"
    dbms=xlsx
    replace;
    sheet="Audit Sample";
run;
