      subroutine CG_linear(ilocal,nline,tol,
     &  wgp_n0,vr,workr_n,kpt,Eref,AL,eigen,
     &  err_st,mxc,mstateT)
****************************************
cc     Written by Lin-Wang Wang, March 30, 2001. 
cc     Copyright 2001 The Regents of the University of California
cc     The United States government retains a royalty free license in this work 
****************************************

      use fft_data
      use load_data
      use data

      implicit double precision (a-h,o-z)

      include 'mpif.h'

      include 'param.escan_real'
***********************************************
      integer status(MPI_STATUS_SIZE)

       complex*16 ugh(mg_nx),ughh(mg_nx)
       complex*16 pg(mg_nx),pgh(mg_nx),pghh(mg_nx)
       complex*16 pg_old(mg_nx),ughh_old(mg_nx)
       complex*16 zg(mg_nx)

       complex*16 wgc_n(mg_nx),wgp_n0(mg_nx,mstateT)
       complex*16, allocatable, dimension (:,:) :: wgp_n,wgp_nh

       real*8 vr(mr_n)
       real*8 prec(mg_nx)
       real*8 AL(3,3)
c       complex*16 workr_n(mg_nx)
       complex*16 workr_n(*)   ! original workr_n is of mr_n which is larger, xwjiang
       complex*16 Zcoeff(mx),zfac,cai
**********************************************
**** if iopt=0 is used, pghh_old can be deleted
**********************************************
       integer lin_st(mst),m_max(mstateT),mxc
       real*8 E_st(mst),err_st(mst),eigen(mst)
       real*8 Eref,coeff(mst)
       complex*16 Zbeta,Zpu

       common /com123b/m1,m2,m3,ngb,nghb,ntype,rrcut,msb
       common /comEk/Ek

       ng_n=ngtotnod(inode,kpt)

       cai=dcmplx(0.d0,1.d0)

       allocate(wgp_n(mg_nx,mstateT))
       allocate(wgp_nh(mg_nx,mstateT))

cccccccccccccccccccccccc

       wgp_n=wgp_n0
       Zcoeff=dcmplx(0.d0,0.d0)

       s=0.0d0
       do i=1,nr/nnodes
       s=s+vr(i)
       enddo
       call global_sumr(s)
       Vavg=s/nr

       do i=1,ng_n
       x=((gkk_n(i,kpt)+Vavg-Eref)/Ek)**2
       prec(i)=1.d0/(1.d0+x)
       enddo

       do i=1,mxc
         dE=eigen(m)-Eref
         if(dE.lt.1.D-20) dE=1.D-20
         coeff(m)=1.D0/(dE**2+err_st**2)
       enddo

       do 4000 iii=1,mstateT

       err2=1.d0
       ughh_old=dcmplx(0.0d0,0.0d0)
       pg_old=dcmplx(0.0d0,0.0d0)
       iopt=1
       zbeta=dcmplx(0.d0,0.d0)

************************************************
**** wgp_nh = (H-Eref) * wgp_n0
************************************************
       call Hpsi_comp(wgp_n(1,iii),wgp_nh(1,iii),ilocal,vr,workr_n,kpt)
       do i=1,ng_n
       wgp_nh(i,iii)=wgp_nh(i,iii)-Eref*wgp_n(i,iii)
       enddo

cccccccccccccccccccccccccccccccccccccccccccc

       rr0=1.d+40
       wgc_n=dcmplx(0.d0,0.d0)


      do 3000 nint2=1,nline

************************************************
**** ughh = (H-Eref)^2 * ug
************************************************
      if(nint2.eq.1) then
        call Hpsi_comp(wgc_n,ugh,ilocal,vr,workr_n,kpt)
        do i=1,ng_n
        ugh(i)=ugh(i)-Eref*wgc_n(i)
        enddo

        call Hpsi_comp(ugh,ughh,ilocal,vr,workr_n,kpt)
        do i=1,ng_n
        ughh(i)=ughh(i)-Eref*ugh(i)
        enddo

      else
        do i=1,ng_n
        ugh(i)=ugh(i)+Zbeta*pgh(i)
        ughh(i)=ughh(i)+Zbeta*pghh(i)
        enddo
      endif

************************************************
      err=0.d0
      E0=0.d0
      E1=0.d0


      do i=1,ng_n
      pg(i)=ughh(i)+wgp_nh(i,iii)
      err=err+cdabs(ugh(i)+wgp_n(i,iii))**2
      E0=E0+dreal(dconjg(wgc_n(i))*(ughh(i)+2*wgp_nh(i,iii)))
      E1=E1+dreal((2*wgp_nh(i,iii)))
      enddo
      call global_sumr(err)
      call global_sumr(E0)
      call global_sumr(E1)
      err=err*vol
      E0=E0*vol
      E1=E1*vol
      err=dsqrt(dabs(err))


      if(err.lt.tol) goto 3001
 
************************************************
      call orth_comp(pg,ug_n,mxc,2,kpt)
************************************************
      err2=0.d0
      do i=1,ng_n
      err2=err2+cdabs(pg(i))**2
      enddo
      call global_sumr(err2)
      err2=dsqrt(dabs(err2*vol))
************************************************
**** begin conjugate gradient
************************************************
      zg=pg
      call orth_comp_N(zg,ug_n,mxc,2,kpt,Zcoeff)
      do i=1,ng_n
        zg(i)=prec(i)*zg(i)
      enddo
      do m=1,mxc
      do i=1,ng_n
        zg(i)=zg(i)+coeff(m)*Zcoeff(m)*ug_n(i,m)
      enddo
      enddo

      rr1=0.d0
      rr00=0.d0
      do i=1,ng_n
      rr00=rr00+zg(i)*dconjg(pg(i))
      rr1=rr1+(zg(i)-iopt*ughh_old(i))*dconjg(pg(i))
      ughh_old(i)=zg(i)
      enddo

      call global_sumr(rr00)
      call global_sumr(rr1)
**********************************************
      beta=rr1/rr0
      rr0=rr00

**********************************************
***** pg(i) is the line minimization direction
**********************************************
       do i=1,ng_n
       pg(i)=-zg(i)+beta*pg_old(i)
       enddo
************************************************
      call orth_comp(pg,ug_n,mxc,2,kpt)

      s=0.d0
      do i=1,ng_n
      s=s+cdabs(pg(i))**2
      enddo
      
      call global_sumr(s)

      s=1/dsqrt(s*vol)

      do i=1,ng_n
      pg_old(i)=pg(i)
      pg(i)=s*pg(i)
      enddo
**********************************************
***** pghh = (H-Eref)^2 * pg
**********************************************

      call Hpsi_comp(pg,pgh,ilocal,vr,workr_n,kpt)

        do i=1,ng_n
        pgh(i)=pgh(i)-Eref*pg(i)
        enddo

      call Hpsi_comp(pgh,pghh,ilocal,vr,workr_n,kpt)

        do i=1,ng_n
        pghh(i)=pghh(i)-Eref*pgh(i)
        enddo
**********************************************
      Zpu=dcmplx(0.d0,0.d0)
      App=0.d0

        do i=1,ng_n
        Zpu=Zpu+dconjg(pg(i))*(ughh(i)+wgp_nh(i,iii))
        App=App+dreal(pg(i)*dconjg(pghh(i)))
        enddo

      call global_sumc(Zpu)
      call global_sumr(App)

      Zpu=Zpu*vol
      App=App*vol
**********************************************
***** Actually, Z is always real !
*****  wgc_new = wgc_n + Z*pg
***** calculate the Z from Zpu and App for line minimization
***** Z is complex
***** E=E0(wgc_n)+ App*Z*Z^* + Z^* * Zpu + Z * Zpu^*
***** Z is Zbeta below
**********************************************
      Zbeta=-Zpu/App

      pred_E=E0+2*dreal(Zpu*dconjg(Zbeta))+
     &     cdabs(Zbeta)**2*App
**********************************************
**** update ug using theta
**********************************************
      do i=1,ng_n
      wgc_n(i)=wgc_n(i)+Zbeta*pg(i)
      enddo

**********************************************
***** debugging:
**********************************************
      if(inode.eq.1) then
      write(6,777) nint2,E0,err,err2
      endif
777   format(i8,3(E20.12,2x))
**********************************************
**** do 3000, is for the nline line minimization
**********************************************
3000  continue
3001  continue


      if(inode.eq.1) then
      write(6,888) nint2,Eref*27.211396d0,E0,err
888   format(i4,"  Eref=",f12.5,"  Emin=",E10.4,1x,
     &  "  err=",E10.2)
	write(6,*) 'nint2,E1',nint2,E1
      endif
cccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccjjjjjjjjjj
cccc output wgc_n in real space, including the phase factor 
ccccccccccccccccccccccccccccccccccc

       call d3fft_comp(wgc_n,workr_n,-1,kpt)

ccccccccccccccccccccccccccccccccccc
cc debug, write out size, xwjiang
c       if(inode.eq.1) then
c         write(6,*) "nr_n = ", nr_n
c         write(6,*) "size(workr_n) = ", size(workr_n)
c       endif

       do ii=1,nr_n
       iit=ii+(inode-1)*nr_n-1
       it=iit/(n3*n2)
       jt=(iit-it*n3*n2)/n3
       kt=iit-it*n3*n2-jt*n3
       xt=AL(1,1)*it/n1+AL(1,2)*jt/n2+AL(1,3)*kt/n3
       yt=AL(2,1)*it/n1+AL(2,2)*jt/n2+AL(2,3)*kt/n3
       zt=AL(3,1)*it/n1+AL(3,2)*jt/n2+AL(3,3)*kt/n3

       workr_n(ii)=workr_n(ii)*cdexp(cai*(
     & xt*akx(kpt)+yt*aky(kpt)+      ! special
     & zt*akz(kpt)))
       enddo

       call mpi_barrier(MPI_COMM_WORLD,ierr)

       if(inode.eq.1) then
       write(17) (workr_n(i),i=1,nr_n)
       endif

       do i=1,nnodes-1
       call mpi_barrier(MPI_COMM_WORLD,ierr)
       if(inode==i+1) then
       call  mpi_send(workr_n,nr_n,MPI_DOUBLE_COMPLEX,0,
     &   100,MPI_COMM_WORLD,ierr)
       endif
       if(inode.eq.1) then
        call mpi_recv(workr_n,nr_n,MPI_DOUBLE_COMPLEX,i,
     &   100,MPI_COMM_WORLD,status,ierr)
       write(17) (workr_n(ii),ii=1,nr_n)
       endif
       enddo

4000  continue


      deallocate(wgp_n)
      deallocate(wgp_nh)
***********************************************

      return
      end

