$TITLE Whole Farm Insurance Model
* Following ideas in papers by Calum Turvey, Keith Coble, etc
* Copyright G. Cornelis van Kooten and Esther Boere
* Thanks to Richard Howitt

$OFFSYMLIST OFFSYMXREF
 OPTION LIMROW = 0
 OPTION LIMCOL = 0
 OPTION RESLIM = 50000
 OPTION ITERLIM = 1000000

OPTION QCP=CPLEX
OPTION NLP=MINOS5;
OPTION DNLP=SNOPT;
*OPTION DNLP=CONOPT;
*OPTION DNLP=MINOS5;

SETS  k  PRODUCTION PROCESSES /wheat, barley, oats, flax, canola/
      J  RESOURCE CONSTRAINTS /land/
*      I  features for crops(PRODUCTION PROCESSES) /cost, pr , yld ,obs /
      s  ITERATIONS IN MONTE CARLO SIMULATION /1*1000/;
*  See McCarl guide for alias http://www.gams.com/mccarl/mccarlhtml/alias.htm?zoom_highlightsub=alias
alias(k,kk);
alias(s,ss);
*--------------------------------------------------------------------
SCALAR ratio Proportion of target revenue to employ /1/;

*SCALARS area, elasbar, elaspot /1668, 0.6 , 2.0/;
*$include scalarsNL.gms

SCALARS elasbar /0.6/;

* See McCarl guide for csv file reading :http://www.gams.com/mccarl/mccarlhtml/$ondelim_and_$offdelim.htm



TABLE input(k, *) Input values obs cost yld pr  created in R file
$ondelim
$include NLinput.csv
$offdelim
;
* -------------- CONTENTS OF INPUT MATRIX CREATED IN R: -------------------
* cost - variable cost in $ per acre
* pr - mean price of the various crops in $ per tonne
* yld - average yield by crop in tonnes per acre
* obs - observed hectares in each of the crops with total ha equal 61.05
* risk - crop-dependent risk parameter

TABLE A(J,k) Unit resource requirements per ha production
      wheat barley oats flax canola
land   1      1      1   1     1
*rot    0      0      1     1     1      0      0
;

PARAMETER R(J)  RESOURCE CONSTRAINTS
          XB(k) OBSERVED LAND USE in hectares
;
    R('land') = sum(k, input(k, 'obs'));
*    R('rot') = R('land')/3;
    XB(k) = input(k,'obs');

*---------------------------------------------------------------
* LINEAR PROGRAM  to find out shadow price
*---------------------------------------------------------------
VARIABLES  LX(k)    ACRES  PLANTED
           LINPROF  LP PROFIT

POSITIVE VARIABLE LX;

EQUATIONS RESOURCE(J)   CONSTRAINED RESOURCES
          CALIB(k)      CALIBRATION CONSTRAINTS
          LPROFIT       LP OBJECTIVE FUNCTION;

RESOURCE(J)..    SUM(k, A(J,k)*LX(k)) =L= R(J);

CALIB(k)$XB(k)..  LX(k) =L= XB(k) *1.001 ;

LPROFIT..    SUM(k, (input(k,'pr')*input(k,'yld') - input(k,'cost'))*LX(k)) =E= LINPROF;

MODEL CALIBRATE / ALL /;
SOLVE CALIBRATE USING LP MAXIMIZING LINPROF;

DISPLAY LX.L, LX.M, RESOURCE.M, CALIB.M ;
*.l = level or primal variable
*.m = marginal or dual variable

*--------------------------------------------------------
PARAMETER
       LAM(k)    PMP DUAL VALUE
       ALPH(k)   INTERCEPT COST
       BETA(k)   COST SLOPE
       ADJ       Adjustment because barley land is not binding
       LAMDA(k)  Revised PMP dual values
       Target    TARGET REVENUE
;
 LAM(k) = 0 ;
*    $(condition) Appending a $-restriction to any subscript(s) makes the operation apply only to subscript combinations satisfying the specified condition. SEE   http://www.che.boun.edu.tr/Courses/che477/Rardin_Notes-on-GAMS-for-Optimization.htm
 LAM(k)$LX.L(k) = CALIB.M(k) ;
* ADJ = 0;
ADJ = input('barley', 'pr')*input('barley', 'yld')/(2*elasbar);
* ADJ = input('edible', 'pr')*input('edible', 'yld')/(2*elaspot);
 LAMDA(k) = LAM(k) + ADJ;
 ALPH(k) =  input(k,'cost') - LAMDA(k) ;
*    $(condition) Appending a $-restriction to any subscript(s) makes the operation apply only to subscript combinations satisfying the specified condition. SEE   http://www.che.boun.edu.tr/Courses/che477/Rardin_Notes-on-GAMS-for-Optimization.htm

 BETA(k)$LX.L(k) =  2*LAMDA(k) / LX.L(k) ;

DISPLAY LAMDA, ALPH,BETA;

*
* Write shadow prices for calibration constraints
*
file shade /shadowad.csv/;
put shade;
  put '', ',' , 'LAMDA', ',', 'ALPH', ',', 'BETA' /;
  loop (k, put k.tl, ',' , LAMDA(k), ',', ALPH(k), ',', BETA(k) /;
);
putclose shade;


*--------------------------------------------------------
*   PMP PROGRAM
*--------------------------------------------------------
VARIABLES  NX(k)    ACRES  PLANTED TO EACH CROP
           NLPROF   NLP PROFIT

POSITIVE VARIABLE NX;

EQUATIONS NRESOURCE(J)  CONSTRAINED RESOURCES
          NLPROFIT      NLP OBJECTIVE FUNCTION;

NRESOURCE(J)..    SUM(k, A(J,k)*NX(k)) =L= R(J);

NLPROFIT.. SUM(k, (input(k,'pr')*input(k,'yld') -
                 (ALPH(k)+0.5*BETA(k)*NX(k)))*NX(k)) =E= NLPROF;

MODEL PMP /NRESOURCE, NLPROFIT /;
* starting value
NX.L(k) = XB(k) * 0.9 ;

SOLVE PMP USING NLP MAXIMIZING NLPROF;

DISPLAY NX.l, nx.m;