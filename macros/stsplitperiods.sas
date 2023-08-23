/* SVN header
$Date: 2018-03-15 12:39:34 +0100 (to, 15 mar 2018) $
$Revision: 93 $
$Author: FCNI6683 $
$Id: stSplitPeriods.sas 93 2018-03-15 11:39:34Z FCNI6683 $
*/
/*
  #+NAME
    %stSplitPeriods
  #+TYPE
    SAS
  #+DESCRIPTION
		Create dataset with person time splitted according to
		specified periods.
		The macro is called outside a datastep.
  #+SYNTAX
    %stSplitPeriods(
      indata,		     Input dataset name with time to be splitted, can be multible rows pr pnr. Required.
      outdata,	     Output dataset name. Required.
      id,		         person id (pnr), in both &indata and &splitdata.
      startdate,	   Variable in indata identifying start of persontime. Required.
      endpoints,     Prefix of endpoint variables, as generated by %genendpoint().
                       Must be in &indata. Required.
      datestub, 	   Postfix of endpoint date variables, as generated by %genendpoint().
                       Must be in &indata. Required.
      statusstub, 	 Postfix of endpoint status variables, as generated by %genendpoint().
                       Must be in &indata. Required.
      splitdata,	   Dataset name with periods defining splits.
      split, 		     Variable in &splitdata indicating status in the period, typically set to 1. Required.
                       Is set to 0 by the macro outside periods in &splitdata.
      splitstart,	   Date of period start. Required.
      splitend	     Date of period end. Required.
  );
  Example:
    data a;
      id=1; sdate='01jun2010'd; D1status=1;D1date='16feb2014'd; D2status=0;D2date='17feb2012'd; output;
      id=2; sdate='11jun2010'd; D1status=1;D1date='05aug2011'd; D2status=0;D2date='05dec2011'd; output;
      format sdate D1date D2date date.;
    run;
    data split1;
      id=1;treat=1;treatstart='01jan2011'd;treatend='15feb2011'd;output;
                   treatstart='17feb2011'd;treatend='15apr2011'd;output;
                   treatstart='17jun2011'd;treatend='15jul2011'd;output;
                   treatstart='17dec2011'd;treatend='15apr2012'd;output;
      format treatstart treatend date.;
    run;
    data split2;
      id=1;beh=1;behstart='01may2011'd;behend='25oct2011'd;output;
      format behstart behend date.;
    run;
    %stSplitPeriods(a,   out1,id,sdate,D1 D2,date,status,split1,treat,treatstart,treatend);
    %stSplitPeriods(out1,out2,id,sdate,D1 D2,date,status,split2,beh,  behstart,  behend);
  #+OUTPUT:
  	All variables in &indata
  	&split
  #+AUTHOR
    Flemming Skj�th
  #+CHANGELOG
    Date		Initials	Status
    07-08-2014	fls		Documentation written, corrected error obtained in the situation of event within a one-day break.
*/
%MACRO stSplitPeriods(indata,outdata,id,startdate,endpoints,datestub,statusstub,splitdata,split,splitstart,splitend);
  %local dstmp1 dstmp2;
  %let dstmp1 =%NewDatasetName(tmp);
  %let elstcnt = %sysfunc(countw(&endpoints));
  data &dstmp1;
    set &splitdata;
    by &id;
    retain lastend;
    output;
    ostart=&splitstart;
    oend=&splitend;
    if first.&id then do;
      &splitend=ostart-1;
      &splitstart='01jan1800'd;
      &split=0;
      output;
    end;
    if first.&id=0 and lastend+1<ostart then do;
      &splitstart=lastend+1;
      &splitend=ostart-1;
      &split=0;
      output;
    end;
    if last.&id then do;
      &splitstart=oend+1;
      &splitend=today()+365;
      &split=0;
      output;
    end;
    lastend=oend;
    drop lastend oend ostart;
  run;
  proc sort data=&dstmp1;
    by &id &splitstart;
  run;
  %let dstmp2 =%NewDatasetName(tmp);
  proc sql;
    create table &dstmp2 as
    select a.*, b.&splitstart, b.&splitend, b.&split
    from &indata a left join &dstmp1 b
    on a.&id=b.&id and a.&startdate<=b.&splitend
    order by &id, &startdate, &splitstart;
  quit;
  data test;
    set &dstmp2;
    data &dstmp2;
    set &dstmp2;
    by &id &startdate;
    %if &elstcnt=1 %then %do;
      lastend=
/*    %let eval=%qscan(&endpoints,1);
      &eval.&datestub;*/
      &endpoints.&datestub;
    %end;
    %if &elstcnt>1 %then %do;
      lastend = max(%commas(%do I=1 %to &elstcnt;
      %let eval = %qscan(&endpoints,&i);
      &eval.&datestub %end;));
    %end;
/*if first.&id and last.&id and &startdate>lastend then output; * no periods, is relevant?;*/;
    if last.&startdate=0 and &splitend<&startdate then delete;
    if first.&startdate=0 and lastend<&startdate then delete;
    if &splitstart=. then output; /* no periods then output*/;
    if &splitstart <= &startdate and &startdate<=&splitend then output; * period during startdate then output;
    if &startdate<&splitstart And &splitstart<=lastend then output; * period after startdate then output;
  run;
  proc sort data=&dstmp2;
    by &id &startdate &splitstart;
  run;
  data &outdata;
    set &dstmp2;
    by &id;
    if &startdate<&splitstart And &splitstart<=lastend then &startdate=&splitstart;
    %do I=1 %to &elstcnt;
      %let eval = %sysfunc(compress(%qscan(&endpoints,&i)));
      if &eval.&datestub>&splitend and &startdate<=&splitend & &eval.&datestub>. then do;
        &eval.&statusstub=0;
        &eval.&datestub=&splitend;
      end;
      if &eval.&datestub<&startdate<=&splitend & &eval.&datestub>. then do;
        &eval.&statusstub=.;
        &eval.&datestub=.;
      end;
    %end;
    if first.&id =0 then &startdate = &startdate - 1;
    drop &splitstart &splitend lastend;
  run;
  %cleanup(&dstmp1 &dstmp2);
  quit;
%MEND;
