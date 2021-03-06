      subroutine add_rho_beta(rho_pL,occ,islda,nkpt,nmap_q,
     &   vtot_pL,E_dDrho)

******************************************
cc     Written by Lin-Wang Wang, March 30, 2001.  
*************************************************************************
**  copyright (c) 2003, The Regents of the University of California,
**  through Lawrence Berkeley National Laboratory (subject to receipt of any
**  required approvals from the U.S. Dept. of Energy).  All rights reserved.
*************************************************************************
******************************************

      use fft_data
      use load_data
      use data

      implicit double precision (a-h,o-z)

      include 'param.escan_real'
      include 'mpif.h'

      real*8 rho_pL(mr_nL,islda),vtot_pL(mr_nL,islda)
      real*8 occ(mst,nkpt,islda)
      complex*16,allocatable,dimension(:,:,:)  :: occ_beta,occ_betatmp

      integer iiatom(mtype),iatom(matom),icore(mtype),numref(matom),
     &  ityatom(matom)
      real*8 occ_t(mtype) 
      real*8 q_LMnm(32,32,49,mtype),q_LMnm0(32,32,12,mtype)
      real*8  q_LM(49,matom),q_LM0(12,matom)
      integer nmap_q(matom)

      integer isNLa(9,matom),ipsp_type(mtype),isps_all
      real*8  Dij0(32,32,mtype),Qij(32,32,mtype)

      complex*16 cc

      common /comNL2/occ_t,iiatom,icore,numref,ityatom
      common /comisNLa/isNLa,Dij0,Qij,ipsp_all,ipsp_type

      common /com_qLMnm/q_LMnm,q_LMnm0


      allocate(occ_beta(mref,mref,natom))
      
       mx_n=mx/nnodes+1

       E_dDrho=0.d0

      do 200 iislda=1,islda

*****************************
      occ_beta=dcmplx(0.d0,0.d0)

       call mpi_barrier(MPI_COMM_WORLD,ierr)
      do 101 kpt=1,nkpt

      if(nkpt.gt.1.or.islda.gt.1) then
       if(icolor_k.eq.0)   then                    ! let only one group to read beta_psi
      call beta_psiIO(beta_psi,kpt,2,0,iislda)
       endif

      call mpi_bcast(beta_psi,nref_tot*mx_n,
     &  MPI_DOUBLE_COMPLEX,0,MPI_COMM_K2,ierr)       ! bcast from icolor=0 to all the other groups
      endif     ! otherwise, beta_psi is already here

      do 100 im=1,mx_n
      m=(inode-1)*mx_n+im
       if(m.le.mx) then
       iref_tt=0
       do ia=1,natom

       do iref1=1,numref(ia)
       iref_t1=iref_tt+iref1

       do iref2=1,numref(ia)
       iref_t2=iref_tt+iref2

       occ_beta(iref1,iref2,ia)=occ_beta(iref1,iref2,ia)+
     &  beta_psi(iref_t1,im)*dconjg(beta_psi(iref_t2,im))
     &  *occ(m,kpt,iislda)
cccc dconjg should be on iref2, tested.

       enddo
       enddo
       iref_tt=iref_tt+numref(ia)
       enddo
       endif

100    continue

101    continue

       allocate(occ_betatmp(mref,mref,natom))
       call mpi_allreduce(occ_beta,occ_betatmp,natom*mref*mref,
     &   MPI_DOUBLE_COMPLEX,MPI_SUM,MPI_COMM_K,ierr)
       occ_beta = occ_betatmp
       deallocate(occ_betatmp)

**************************

       do ia=1,natom
       itype=ityatom(ia)
         if(ipsp_type(itype).eq.2) then
       do LM=2,49       ! LM is a combined index of (L,M), L=0,...,6
       cc=dcmplx(0.d0,0.d0)
       do iref2=1,numref(ia)
       do iref1=1,numref(ia)
       cc=cc+q_LMnm(iref1,iref2,LM,itype)*occ_beta(iref1,iref2,ia)
       enddo
       enddo
ccccc occ_beta(iref1,iref2,ia)=dconjg(occ_beta(iref2,iref1,ia))
       q_LM(LM,ia)=dreal(cc)      ! check, cc should be already real here
       enddo

       do LM0=1,12       ! LM0 is the index for LM=(0,0) and the cases of l(iref1)=l(iref2)
       cc=dcmplx(0.d0,0.d0)
       do iref2=1,numref(ia)
       do iref1=1,numref(ia)
       cc=cc+q_LMnm0(iref1,iref2,LM0,itype)*occ_beta(iref1,iref2,ia)
       enddo
       enddo
       q_LM0(LM0,ia)=dreal(cc)      ! check, cc should be already real here
       enddo

         endif    ! ipsp_type.eq.2
       enddo      ! ia=1,natom

******** d_rho= \sum_LM q_LM(LM,ia)* wmask_q(LM,r-ia)+\sum_LM0 q_LM0(LM0,ia)*wmask_q(LM0,r-ia)

       ico=0
       do ia=1,natom
       do i=1,nmap_q(ia)
       ico=ico+1
       sum=0.d0
       do LM=2,49         ! special treatment for LM=1, by LM0
       sum=sum+wmask_q(LM,ico)*q_LM(LM,ia)
       enddo
       do LM0=1,12
       sum=sum+wmask_q0(LM0,ico)*q_LM0(LM0,ia)
       enddo
       rho_pL(indm_q(ico),iislda)=rho_pL(indm_q(ico),iislda)+sum
       E_dDrho=E_dDrho+sum*vtot_pL(indm_q(ico),iislda)
       enddo
       enddo

*****************************************8
200    continue

       call mpi_allreduce(E_dDrho,E_dDrhotmp,1,
     & MPI_REAL8,MPI_SUM,MPI_COMM_K,ierr)
       E_dDrho = E_dDrhotmp

       E_dDrho=E_dDrho*vol/(n1L*n2L*n3L)

       deallocate(occ_beta)

ccccccc  test
       nr_nL=n1L*n2L*n3L/nnodes
       n_test=0
       do iislda=1,islda
       do i=1,nr_nL
       if(rho_pL(i,iislda).lt.0.d0) n_test=n_test+1
       enddo
       enddo

       call mpi_allreduce(n_test,n_testtmp,1,
     & MPI_INTEGER,MPI_SUM,MPI_COMM_K,ierr)
       n_test = n_testtmp

       if(inode.eq.1) then
       write(6,*) "number of negative rho_nL grid points=", n_test
       endif


       return
       end




