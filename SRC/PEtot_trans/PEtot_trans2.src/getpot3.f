      subroutine getpot3(rho,vion,rhocr,vtot,v0,E_Hxc,workr_n,
     &  E_coul,E_ion)
******************************************
cc     Written by Lin-Wang Wang, March 30, 2001.  
cc     Copyright 2001 The Regents of the University of California
cc     The United States government retains a royalty free license in this work
******************************************


      use fft_data
      use load_data
      use data

      implicit double precision (a-h,o-z)
      include 'param.escan_real'

      real*8 workr_n(mr_n)
      real*8 vtot(mr_n,2)
      real*8 rho(mr_n,2),vion(mr_n),rhocr(mr_n)

      real*8 vi(mr_n)

**************************************************
ccccc generate the potential vtot from rho(i)

      ng2_n=ngtotnod2(inode)

      vi = 0.0d0

      do i=1,nr_n
      workr_n(i) = rho(i,1)+rho(i,2)     ! total charge for Coulomb potential
      enddo

      call d3fft_real2(vi,workr_n,1,0)


      pi=4*datan(1.d0)

      do 100 i=1,ng2_n
 
      if(inode.eq.iorg2(1).and.i.eq.iorg2(2)) then
      ig = iorg2(2)
      vi(ig*2)=0.d0
      vi(ig*2-1)=0.d0
      else
      vi(i*2)=vi(i*2)*2*pi/gkk2_n(i)
      vi(i*2-1)=vi(i*2-1)*2*pi/gkk2_n(i)
      endif

100   continue

      call d3fft_real2(vi,workr_n,-1,0)

      
      do iislda=1,2
      do i=1,nr_n
      vtot(i,iislda) = workr_n(i)
      enddo
      enddo


      
      s=0.d0
      E_Hxc=0.d0
      E_coul=0.d0
      E_ion=0.d0


      do i=1,nr_n
      E_Hxc=E_Hxc+0.5d0*(vtot(i,1)*rho(i,1)+
     &                   vtot(i,2)*rho(i,2))
      E_coul=E_coul+0.5d0*(vtot(i,1)*rho(i,1)+
     &                   vtot(i,2)*rho(i,2))
      E_ion=E_ion+vion(i)*(rho(i,1)+rho(i,2))
      call UxcCA2(dabs(rho(i,1)+rhocr(i)*0.5d0),
     &    dabs(rho(i,2)+rhocr(i)*0.5d0),
     &    vxc1,vxc2,uxc1,uxc2)
      vtot(i,1)=vtot(i,1)+vion(i)+vxc1
      vtot(i,2)=vtot(i,2)+vion(i)+vxc2
      E_Hxc=E_Hxc+uxc1*dabs(rho(i,1)+rhocr(i)*0.5d0)+
     &         uxc2*dabs(rho(i,2)+rhocr(i)*0.5d0)
      s=s+(vtot(i,1)+vtot(i,2))*0.5d0
      enddo

 
      do iislda=1,2
      do i=1,nr_n
      workr_n(i) = vtot(i,iislda)
      enddo

***** only keep the G components within Ecut2
      call d3fft_real2(vtot(1,iislda),workr_n,1,0)
      call d3fft_real2(vtot(1,iislda),workr_n,-1,0)
***** we can save one fft by rearrange the order.

      do i=1,nr_n
      vtot(i,iislda) = workr_n(i)
      enddo
      enddo

      call global_sumr(s)
      call global_sumr(E_Hxc)
      call global_sumr(E_coul)
      call global_sumr(E_ion)

      E_Hxc=E_Hxc*vol/nr
      E_coul=E_coul*vol/nr
      E_ion=E_ion*vol/nr

      s=s/nr
      do i=1,nr_n
      vtot(i,1)=vtot(i,1)-s
      vtot(i,2)=vtot(i,2)-s
      enddo

      v0=s
ccccccccccccccccccccc
cccccc ave_vtot=0.d0 is necessary for mch_Broyden and mch_pulay,
cccccc otherwise it doesn't work
ccccccccccccccccccccc


      return
      end
      

