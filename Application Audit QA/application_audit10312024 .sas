
/* Define libraries, audit parameters */

libname coves odbc dsn=coves schema=dbo;

/* Create Temp DFs for Query and Report */
proc sql;
	create table work.county as
		select *
			from coves.county
				where not missing (cGeoCode);
quit;

proc sql;
	create table work.Request as
		select nRequestID, cRequestorTownFips, nRequestCreatedLocation, cRequestorFirstName, cRequestorLastName, nRequestLocationID, cRequestTypeDesc, dRequestCreatedDTS
			from coves.feerequest
				where year(dRequestCreatedDTS) = 2024;
quit;




proc sql;
	create table work.Transaction as
		select nTransID, cTransCertificateName, cTransCertificateSFN, cTransStatusID, cTransStatusDesc, dTransCompletedDate, nRequestID, cTransCategoryID, cTransCategoryDesc, cTransTypeID, cTransTypeDesc
			from coves.FeeTransaction
				where year(dTransCompletedDate) = 2024;
quit;

proc sql;
	create table work.birthregistrant as
		select nTransID, nRegistrantCountyofEventID, cRegistrantCountyofEventName, cRegistrantEventDate, cRegistrantSFN, cRegistrantFName, cRegistrantLName
			from coves.FeeBirthRegistrant
				where year(dcreateddate) = 2024;
run;

proc sql;
	create table work.deathregistrant as
		select nTransID, nRegistrantCountyofEventID, cRegistrantCountyofEventName, cRegistrantEventDate, cRegistrantSFN, cRegistrantFName, cRegistrantLName
			from coves.FeeDeathRegistrant
				where year(dCreatedDate) = 2024;
run;

proc print data= request (obs=20); run; 
proc print data= transaction (obs=20); run; 
proc print data= birthregistrant (obs=20); run; 
proc print data= deathregistrant (obs=20); run; 
proc print data= county; run; 

proc contents data=request; run; 
proc contents data=transaction; run; 
proc contents data=birthregistrant; run; 
proc contents data= deathregistrant; run; 
proc contents data=county; run; 

/*Filter Data to Query Specifications */
proc freq data=transaction;
	table cTransCategoryID * cTransCategoryDesc;
run;

proc freq data=deathregistrant; 
table cRegistrantCountyofEventName * nRegistrantCountyofEventID;  
where cRegistrantCountyofEventName in ('DENVER'); 
run; 

/* Merge Data for Reporting? */

