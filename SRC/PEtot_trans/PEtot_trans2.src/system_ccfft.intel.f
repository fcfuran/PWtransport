      subroutine system_ccfft(init,isign,n,scale,x,y,
     &           table,work,isys,ntable,nwork)
****************************************************
*** Written by Lin-Wang Wang, 2001
*************************************************************************
**  copyright (c) 2003, The Regents of the University of California,
**  through Lawrence Berkeley National Laboratory (subject to receipt of any
**  required approvals from the U.S. Dept. of Energy).  All rights reserved.
*************************************************************************

      implicit none
      integer init,isign,n,isys,ntable,nwork,info,i
      real*8 scale,table(*),work(*)
      real*8 x(*),y(*),fact
cccccccc complex to complex 1D FFT

cccccc for XT3
c      if(init.eq.1) then
c      call zzfft(0,n,scale,0,0,table,0,0)
c      else
c      call zzfft(isign,n,scale,x,y,table,work,isys)
c      endif
cccccc for T3E
c      if(init.eq.1) then
c      call ccfft(0,n,scale,0,0,table,0,0)
c      else
c      call ccfft(isign,n,scale,x,y,table,work,isys)
c      endif
cccccccccccccccccccccc
cccccc for IBM SP2, essl lib
c      if(init.eq.1) then
c      call dcft(1,0,1,0,0,1,0,
c     &    n,1,-isign,scale,table,ntable,0,0)
c      else
c      call dcft(0,x,1,0,y,1,0,n,1,-isign,scale,
c     &    table,ntable,work,nwork) 
c      endif
cccccccccccccccccccccccccccccccccccc
ccccccccc  for Intel KML lib
       if(init.eq.1) then
       call zfft1d(y,n,0,table)
       else
       do i=1,2*n
       y(i)=x(i)
       enddo
       call zfft1d(y,n,isign,table)
       if(isign.eq.1) then
       do i=1,2*n
       y(i)=y(i)*n*scale
       enddo
       endif
       endif
ccccccccccccccccccccccccccccccccccccccc
ccccccccc  for AMD ACML lib
c       if(init.eq.1) then
c       call zfft1d(0,n,y,table,info)
c       else
c       fact=dsqrt(n*1.d0)*scale        ! this is bad, should this outside
c
c       y(1:2*n)=fact*x(1:2*n)  !see if this improves vectorization
c
c!       do i=1,2*n
c!       y(i)=x(i)*fact
c!       enddo
c
c       call zfft1d(isign,n,y,table,info)
c       endif
ccccccccccccccccccccccccccccccccccccccc

                                                                                                                                                                         

      return
      end

 
      

