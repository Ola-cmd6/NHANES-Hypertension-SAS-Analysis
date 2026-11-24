/* 1. Use a shorter library name (8 characters or less) */
LIBNAME nh_demo XPORT '/home/u64655675/DEMO_J.xpt';
PROC COPY IN=nh_demo OUT=work;
RUN;

/* 2. Do the same for the BPX file */
LIBNAME nh_bpx XPORT '/home/u64655675/BPX_J.xpt';
PROC COPY IN=nh_bpx OUT=work;
RUN;


/* 3. Merge the datasets */
DATA nhanes_merged;
    MERGE work.demo_j (KEEP=SEQN RIDAGEYR RIAGENDR RIDRETH1 INDFMPIR WTMEC2YR SDMVPSU SDMVSTRA)
          work.bpx_j (KEEP=SEQN BPXSY1 BPXDI1);
    BY SEQN;
RUN;

/* 4. Confirm it worked */
PROC PRINT data=nhanes_merged (obs=10); RUN;


/* 4. Clean and Recode Variables (Updated with LENGTH) */
DATA nhanes_clean;
    SET nhanes_merged;

    /* Tell SAS to make these text columns long enough so they don't get cut off */
    LENGTH Gender $ 6 Race $ 25 Income_Cat $ 25 Age_Group $ 6;

    /* --- A. Keep only adults (18 and older) --- */
    IF RIDAGEYR < 18 OR RIDAGEYR = . THEN DELETE;

    /* --- B. Recode Categorical Variables --- */
    IF RIAGENDR = 1 THEN Gender = "Male";
    ELSE IF RIAGENDR = 2 THEN Gender = "Female";

    IF RIDRETH1 = 1 THEN Race = "Mexican American";
    ELSE IF RIDRETH1 = 2 THEN Race = "Other Hispanic";
    ELSE IF RIDRETH1 = 3 THEN Race = "Non-Hispanic White";
    ELSE IF RIDRETH1 = 4 THEN Race = "Non-Hispanic Black";
    ELSE IF RIDRETH1 = 5 THEN Race = "Other/Multi-Racial";

    IF RIDAGEYR >= 18 AND RIDAGEYR < 40 THEN Age_Group = "18-39";
    ELSE IF RIDAGEYR >= 40 AND RIDAGEYR < 60 THEN Age_Group = "40-59";
    ELSE IF RIDAGEYR >= 60 THEN Age_Group = "60+";

    IF NOT MISSING(BPXSY1) AND NOT MISSING(BPXDI1) THEN DO;
        IF BPXSY1 >= 130 OR BPXDI1 >= 80 THEN Hypertension = 1;
        ELSE Hypertension = 0;
    END;
    ELSE Hypertension = .; 

    IF INDFMPIR < 1 THEN Income_Cat = "< 1.0 (Below Poverty)";
    ELSE IF INDFMPIR >= 1 AND INDFMPIR < 3 THEN Income_Cat = "1.0 - 2.99";
    ELSE IF INDFMPIR >= 3 THEN Income_Cat = ">= 3.0 (Higher Income)";
    ELSE Income_Cat = "Missing";

RUN;


PROC FREQ data=nhanes_clean;
    TABLES Gender Race Age_Group Hypertension Income_Cat / MISSING;
RUN;





/* Plot 1: Bar chart of Hypertension by Age and Gender */
PROC SGPLOT data=nhanes_clean;
    VBAR Age_Group / GROUP=Gender STAT=PERCENT GROUPDISPLAY=CLUSTER;
    XAXIS VALUES=("18-39" "40-59" "60+") LABEL="Age Group";
    YAXIS LABEL="Prevalence of Hypertension (%)";
    TITLE "Prevalence of Hypertension by Age Group and Gender";
RUN;




/* Plot 2: Scatter plot of Systolic BP vs Age */
PROC SGPLOT data=nhanes_clean;
    SCATTER X=RIDAGEYR Y=BPXSY1 / GROUP=Gender TRANSPARENCY=0.5;
    REG X=RIDAGEYR Y=BPXSY1 / GROUP=Gender;
    XAXIS LABEL="Age (Years)";
    YAXIS LABEL="Systolic Blood Pressure (mmHg)";
    TITLE "Systolic Blood Pressure by Age and Gender";
RUN;



/* Plot 3: Hypertension by Income Category */
PROC SGPLOT data=nhanes_clean;
    /* Note: We filter out missing income for a cleaner plot */
    WHERE Income_Cat NE "Missing"; 
    VBAR Income_Cat / STAT=PERCENT FILLATTRS=(COLOR=SteelBlue);
    XAXIS LABEL="Income-to-Poverty Ratio";
    YAXIS LABEL="Prevalence of Hypertension (%)";
    TITLE "Hypertension Prevalence by Socioeconomic Status";
RUN;




/* 6. Multivariable Logistic Regression (Survey-Weighted) */
PROC SURVEYLOGISTIC data=nhanes_clean;
    /* Specify the survey design variables */
    STRATA SDMVSTRA;
    CLUSTER SDMVPSU;
    WEIGHT WTMEC2YR;
    
    /* Specify categorical variables and choose the reference groups */
    CLASS Gender (REF="Male") 
          Race (REF="Non-Hispanic White") 
          Income_Cat (REF=">= 3.0 (Higher Income)") / PARAM=REF;
    
    /* The Model: Predicting Hypertension (Event = 1) */
    /* Changed the option to just EXPB */
    MODEL Hypertension (EVENT='1') = RIDAGEYR Gender Race Income_Cat / EXPB;
          
    TITLE "Multivariable Survey-Weighted Logistic Regression: Predictors of Hypertension";
RUN;