       SUBROUTINE ZESEC(T)
C
C      GETS CPU TIME IN SECONDS
C      CRAY-2 VERSION
C
C      REAL*8 T
       T = SECOND()
       RETURN
       END
C
       SUBROUTINE ZEDATE(BDATE)
C
C      GETS THE DATE (DAY-MONTH-YEAR)
C      CRAY-2 VERSION
C
       CHARACTER*10 BDATE
       CHARACTER*8 ADATE
       CHARACTER*3 MONTH(12)
       CHARACTER*1 DASH,DUM1,DUM2
       DATA DASH/'-'/
       DATA MONTH/'JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP',
     2            'OCT','NOV','DEC'/
C       
       WRITE(ADATE,100) DATE()
       READ(ADATE,101) LMONTH,DUM1,LDAY,DUM2,LYEAR
       WRITE(BDATE,102) LDAY,DASH,MONTH(LMONTH),DASH,LYEAR,' '
 100   FORMAT(A8)
 101   FORMAT(I2,A1,I2,A1,I2)
 102   FORMAT(I2,A1,A3,A1,I2,A1)
       RETURN
       END


