
#undef BL_LANG_CC
#ifndef BL_LANG_FORT
#define BL_LANG_FORT
#endif

#include <AMReX_REAL.H>
#include <AMReX_CONSTANTS.H>
#include <AMReX_BC_TYPES.H>
#include <AMReX_ArrayLim.H>
#include <infl_frc.H>
#include <FLUCTFILE.H>

#define SDIM 2

! ::: -----------------------------------------------------------
! ::: This routine does the interpolation of the inflow data
! ::: 
! ::: INPUTS/OUTPUTS:
! ::: 
! ::: time              =>  Time at which to fill the data
! ::: xlo               =>  Lower physical location of the inflDat array
! ::: dx                =>  Grid spacing in the inflDat array
! ::: storePnt          =>  Interpolation point in the strmwse_dir direction
! ::: fillComp          =>  Component from the storDat array to use
! ::: timePnt           =>  Physical time corresponding to the storePnt point
! :::                         in the data in storDat
! ::: dtFile            =>  Time step in the array storDat
! ::: nCompStorDat      =>  Number of components in the storDat array
! ::: FF_DIMS(storDat)  =>  Dimensions of storDat
! ::: storDat           =>  Array to fill
! ::: DIMS(inflDat)     =>  Dimensions of the inflDat array
! ::: inflDat          <=   Array to fill by interpolating from the storDat 
! :::                         array
! ::: -----------------------------------------------------------
! :::
! ::: NOTE:  When x and y are calculated for each i and j index
! :::        in this routine, they are calculated based on formulaes
! :::        of the form,
! :::            x = probLo(1) + dx(1) * (DBLE(i) + half)
! :::        rather than on the more common form,
! :::            x = xlo(1) + dx(1) * (DBLE(i - lo(1)) + half)
! :::        In other words, they are calculated based on the origin
! :::        of the problem domain rather than the origin of the FAB
! :::        we are working on.  This forces the physical location for
! :::        some specified index to be identically the same no matter
! :::        which FAB we are working on.  Seems like a moot point, but
! :::        it isn't when we do an integer shift to force points outside 
! :::        of the domain in periodic directions.
! :::        
! :::        For instance if we have a domain from 0->63 in a periodic 
! :::        direction and pass in a FAB to fill with indices from -1 to 5,
! :::        the -1 index is integer shifted over to an index of 63 to do
! :::        the interpolation for the forcing.
! :::
      subroutine INTRP_DATA(time, dx, storePnt, fillComp, filePnt, &
          timePnt, dtFile, dxFile, xloFile, xhiFile, nCompStorDat, &
          FF_DIMS(storDat), storDat, &
          DIMS(inflDat), inflDat, bc, probLo, probHi)

      implicit none

      integer storePnt, fillComp, filePnt, nCompStorDat
      integer DIMDEC(inflDat)
      integer FF_DIMDEC(storDat)
      integer bc(SDIM,2)

      REAL_T time, timePnt, dtFile
      REAL_T xlo(SDIM), dx(SDIM), dxFile(3), xloFile(3), xhiFile(3)
      REAL_T probLo(SDIM), probHi(SDIM)
      REAL_T inflDat(DIMV(inflDat))
      REAL_T storDat(FF_DIMV(storDat),nCompStorDat)

      integer i, j, iloc, jloc, kloc, ixcalc, jycalc
      integer lo(SDIM), hi(SDIM), n_lev_cells(SDIM)
      integer loStorDim(3), hiStorDim(3)
      REAL_T tm1, tp1, ctm1, ct0, ctp1, coff, &
            x, xm1, x0, xp1, cxm1, cx0, cxp1, &
            y, ym1, y0, yp1, cym1, cy0, cyp1, &
            val0

#include <INFL_FORCE_F.H>

      call SET_LOHI(DIMS(inflDat), lo, hi)
      call FF_SET_LOHI(FF_DIMS(storDat), loStorDim, hiStorDim)

      do i = 1, SDIM
        n_lev_cells(i) = (probHi(i) - probLo(i)) / dx(i)
      enddo

      if (infl_type .eq. infl_periodic_type) then
         coff = one
         tm1  = timePnt - dtFile
         tp1  = timePnt + dtFile
      else if (infl_type .eq. infl_swirl_type) then
         coff = half
         tm1  = fluct_times(filePnt - 1)
         tp1  = fluct_times(filePnt + 1)
      else
         call bl_abort('INTRP_DATA: unknown infl_type')
      endif

      ctm1 = (time - timePnt) * (time - tp1) / (tm1 - timePnt) / (tm1 - tp1)
      ct0  = (time - tm1) * (time - tp1) / (timePnt - tm1) / (timePnt - tp1)
      ctp1 = (time - tm1) * (time - timePnt) / (tp1 - tm1) / (tp1 - timePnt)
!
!     ----------------------------------------------
!     :::: Interpolate to fill the inflow array ::::
!     ----------------------------------------------
!
      if (strmwse_dir .eq. FLCT_XVEL) then
!
!     :::: Streamwise X-direction ::::
!
        kloc = 1

        do j = lo(2), hi(2)
          jycalc = j
          if (bc(2,1) .eq. INT_DIR .and. j .lt. 0) then
            jycalc = j + n_lev_cells(2)
          else if (bc(2,2) .eq. INT_DIR .and. j .ge. n_lev_cells(2)) then
            jycalc = j - n_lev_cells(2)
          endif
          y = probLo(2) + dx(2)*(DBLE(jycalc) + half)

          if ((xloFile(2) .le. y .and. y .le. xhiFile(2))) then
            jloc = (y - xloFile(2) + half*dxFile(2))/dxFile(2) + 1
            jloc = MAX(jloc, loStorDim(2)+1)
            jloc = MIN(jloc, hiStorDim(2)-1)
            y0 = (DBLE(jloc)-coff) * dxFile(2) + xloFile(2)
            ym1 = y0 - dxFile(2)
            yp1 = y0 + dxFile(2)
            cym1 = (y - y0)  * (y - yp1) / (ym1 - y0)  / (ym1 - yp1)
            cy0  = (y - ym1) * (y - yp1) / (y0  - ym1) / (y0  - yp1)
            cyp1 = (y - ym1) * (y - y0)  / (yp1 - ym1) / (yp1 - y0)

            val0 = cym1 * (ctm1 * storDat(storePnt-1,jloc-1,kloc,fillComp) &
                        +  ct0 * storDat(storePnt, jloc-1,kloc,fillComp) &
                        + ctp1 * storDat(storePnt+1,jloc-1,kloc,fillComp)) &
                +  cy0 * (ctm1 * storDat(storePnt-1,jloc, kloc,fillComp) &
                        +  ct0 * storDat(storePnt,  jloc, kloc,fillComp) &
                        + ctp1 * storDat(storePnt+1,jloc, kloc,fillComp)) &
                + cyp1 * (ctm1 * storDat(storePnt-1,jloc+1,kloc,fillComp) &
                        +  ct0 * storDat(storePnt, jloc+1,kloc,fillComp) &
                        + ctp1 * storDat(storePnt+1,jloc+1,kloc,fillComp))

          else
            val0 = zero
          endif

          do i = lo(1), hi(1)
            inflDat(i,j) = val0
          enddo
        enddo
        
        elseif (strmwse_dir .eq. FLCT_YVEL) then
!
!     :::: Streamwise Y-direction ::::
!
        kloc = 1

        do i = lo(1), hi(1)
          ixcalc = i
          if (bc(1,1) .eq. INT_DIR .and. i .lt. 0) then
            ixcalc = i + n_lev_cells(1)
          else if (bc(1,2) .eq. INT_DIR .and. i .ge. n_lev_cells(1)) then
            ixcalc = i - n_lev_cells(1)
          endif
          x = probLo(1) + dx(1)*(DBLE(ixcalc) + half)

          if (xloFile(1) .le. x .and. x .le. xhiFile(1)) then
            iloc = (x - xloFile(1) + half*dxFile(1))/dxFile(1) + 1
            iloc = MAX(iloc, loStorDim(1)+1)
            iloc = MIN(iloc, hiStorDim(1)-1)
            x0 = (DBLE(iloc)-coff) * dxFile(1) + xloFile(1)
            xm1 = x0 - dxFile(1)
            xp1 = x0 + dxFile(1)
            cxm1 = (x - x0)  * (x - xp1) / (xm1 - x0)  / (xm1 - xp1)
            cx0  = (x - xm1) * (x - xp1) / (x0  - xm1) / (x0  - xp1)
            cxp1 = (x - xm1) * (x - x0)  / (xp1 - xm1) / (xp1 - x0)

            val0 = cxm1 * (ctm1 * storDat(iloc-1,storePnt-1,kloc,fillComp) &
                        +  ct0 * storDat(iloc-1,storePnt, kloc,fillComp) &
                        + ctp1 * storDat(iloc-1,storePnt+1,kloc,fillComp)) &
                +  cx0 * (ctm1 * storDat(iloc, storePnt-1,kloc,fillComp) &
                        +  ct0 * storDat(iloc,  storePnt, kloc,fillComp) &
                        + ctp1 * storDat(iloc, storePnt+1,kloc,fillComp)) &
                + cxp1 * (ctm1 * storDat(iloc+1,storePnt-1,kloc,fillComp) &
                        +  ct0 * storDat(iloc+1,storePnt, kloc,fillComp) &
                        + ctp1 * storDat(iloc+1,storePnt+1,kloc,fillComp))

          else
            val0 = zero
          endif

          do j = lo(2), hi(2)
            inflDat(i,j) = val0
          enddo
        enddo

      endif

      end


