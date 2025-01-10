

%let in_path = C:\sas_input\birth;
%let out_path = C:\sas_output\birth;
%let file_suffix = EAB;

/* Ensure the output directory exists */
options noxwait;
x "if not exist &out_path mkdir &out_path";

/* Get today's date in MMDDYY format */
data _null_;
    call symputx('today_date', put(today(), mmddyyn6.));
run;

/* Step 1: Read file names */
filename filelist pipe "dir /b ""&in_path""";
data files;
    infile filelist truncover;
    input filename $100.;
    filename = strip(filename);
    length filepath $200;
    filepath = cats("&in_path\", filename);
run;

/* Step 2: Read files and exclude the first and last lines */
data combined_data;
    length line $380; /* Record size */
    retain valid_count 0; /* Count of valid records */
    set files; /* Input file list */
    infile dummy filevar=filepath lrecl=380 end=eof truncover;

    _line + 1; /* Line counter */
    input line $char380.;

    /* Skip first line (_line = 1) and last line (eof flag) */
    if _line > 1 and not eof then do;
        valid_count + 1; /* Count only valid records */
        output; /* Write valid data lines to combined_data */
    end;

    /* Reset the line counter for the next file */
    if eof then do;
        _line = 0; 
    end;
run;

/* Step 3: Write the master file with accurate header and footer */
data _null_;
    file "&out_path.\SCO.&today_date..&file_suffix" lrecl=381;
    set combined_data end=last;

    /* Pad each line to 381 characters */
    length padded_line $381;
    padded_line = catx(' ', line, repeat(' ', 381 - lengthn(line)));

    /* Write the header once */
    if _n_ = 1 then do;
        header = cats('ESEAB.CO', "&today_date", '999999');
        header = catx(' ', header, repeat(' ', 381 - lengthn(header)));
        put header $381.;
    end;

    /* Write valid data lines */
    put padded_line $381.;

    /* Write the footer once at the end */
    if last then do;
        footer = cats('ESEAB.CO', "&today_date", '999999',
                      put(_n_ - 1, z6.), /* Total valid records */
                      put(_n_ - 1, z6.)); /* Repeated for consistency */
        footer = catx(' ', footer, repeat(' ', 381 - lengthn(footer)));
        put footer $381.;
    end;
run;
