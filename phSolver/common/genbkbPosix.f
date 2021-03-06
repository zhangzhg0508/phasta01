        subroutine genbkbPosix (ibksz)
c
c----------------------------------------------------------------------
c
c  This routine reads the boundary elements, reorders them and
c  generates traces for the gather/scatter operations.
c
c Zdenek Johan, Fall 1991.
c----------------------------------------------------------------------
c
        use dtnmod
        use pointer_data
        use phio
        use iso_c_binding
        include "common.h"
        include "mpif.h" !Required to determine the max for itpblk

        integer, target, allocatable :: ientp(:,:),iBCBtp(:,:)
        real*8, target, allocatable :: BCBtp(:,:)
        integer materb(ibksz)
        integer, target :: intfromfile(50) ! integers read from headers
        character*255 fname1
        integer :: descriptor, descriptorG, GPID, color, nfields
        integer :: numparts, nppp, nprocs, writeLock
        integer :: ierr_io, numprocs, itmp, itmp2 
        integer, target :: itpblktot,ierr
        character*255 fname2
        character(len=30) :: dataInt, dataDbl
        dataInt = c_char_'integer'//c_null_char
        dataDbl = c_char_'double'//c_null_char

        nfields = nsynciofieldsreadgeombc
        numparts = numpe !This is the common settings. Beware if you try to compute several parts per process
        nppp = numparts/numpe
        ione=1
        itwo=2
        ieight=8
        ieleven=11
        itmp = int(log10(float(myrank+1)))+1
        iel=1
        itpblk=nelblb
        nelblb=0
        mattyp=0
        ndofl = ndof
        do iblk = 1, itpblk
           write (fname2,"('connectivity boundary?')") 
           call phio_readheader(fhandle, fname2 // char(0),
     &      c_loc(intfromfile), ieight, dataInt, iotype)
           neltp =intfromfile(1)
           nenl  =intfromfile(2)
           ipordl=intfromfile(3)
           nshl  =intfromfile(4)
           nshlb =intfromfile(5)
           nenbl =intfromfile(6)
           lcsyst=intfromfile(7)
           numnbc=intfromfile(8)

           allocate (ientp(neltp,nshl))
           allocate (iBCBtp(neltp,ndiBCB))
           allocate (BCBtp(neltp,ndBCB))
           iientpsiz=neltp*nshl


           call phio_readdatablock(fhandle, fname2 // char(0),
     &      c_loc(ientp),iientpsiz,dataInt,iotype)
c     
c.... Read the boundary flux codes
c

               write (fname2,"('nbc codes?')")

           call phio_readheader(fhandle, fname2 // char(0),
     &      c_loc(intfromfile), ieight, dataInt, iotype)
           iiBCBtpsiz=neltp*ndiBCB
           call phio_readdatablock(fhandle, fname2 // char(0),
     &      c_loc(iBCBtp),iiBCBtpsiz,dataInt,iotype)
c     
c.... read the boundary condition data
c     
               write (fname2,"('nbc values?')")

           call phio_readheader(fhandle, fname2 // char(0),
     &      c_loc(intfromfile), ieight, dataInt, iotype)
           BCBtp    = zero
           iBCBtpsiz=neltp*ndBCB
           call phio_readdatablock(fhandle, fname2 // char(0),
     &      c_loc(BCBtp),iBCBtpsiz,dataDbl,iotype)
c
c This is a temporary fix until NSpre properly zeros this array where it
c is not set.  DEC has indigestion with these arrays though the
c result is never used (never effects solution).
c

           where(.not.btest(iBCBtp(:,1),0)) BCBtp(:,1)=zero
           where(.not.btest(iBCBtp(:,1),1)) BCBtp(:,2)=zero
           where(.not.btest(iBCBtp(:,1),3)) BCBtp(:,6)=zero
           if(ndBCB.gt.6) then
             do i=6,ndof
               where(.not.btest(iBCBtp(:,1),i-1)) BCBtp(:,i+1)=zero
             enddo
           endif
           where(.not.btest(iBCBtp(:,1),2)) 
              BCBtp(:,3)=zero
              BCBtp(:,4)=zero
              BCBtp(:,5)=zero
           endwhere


           do n=1,neltp,ibksz 
              nelblb=nelblb+1
              npro= min(IBKSZ, neltp - n + 1)
c
              lcblkb(1,nelblb)  = iel
c              lcblkb(2,nelblb)  = iopen ! available for later use
              lcblkb(3,nelblb)  = lcsyst
              lcblkb(4,nelblb)  = ipordl
              lcblkb(5,nelblb)  = nenl
              lcblkb(6,nelblb)  = nenbl
              lcblkb(7,nelblb)  = mattyp
              lcblkb(8,nelblb)  = ndofl
              lcblkb(9,nelblb)  = nshl 
              lcblkb(10,nelblb) = nshlb ! # of shape functions per elt
c
c.... save the element block
c
              n1=n
              n2=n+npro-1
              materb=1   ! all one material for now
c
c.... allocate memory for stack arrays
c

              allocate (mienb(nelblb)%p(npro,nshl))
              allocate (miBCB(nelblb)%p(npro,ndiBCB))
              allocate (mBCB(nelblb)%p(npro,nshlb,ndBCB))
              allocate (mmatb(nelblb)%p(npro))
c
c.... save the boundary element block
c
              call gensvb (ientp(n1:n2,1:nshl),
     &                 iBCBtp(n1:n2,:),      BCBtp(n1:n2,:),
     &                 materb,        mienb(nelblb)%p,
     &                 miBCB(nelblb)%p,        mBCB(nelblb)%p,
     &                 mmatb(nelblb)%p)
c
              iel=iel+npro
           enddo
           deallocate(ientp)
           deallocate(iBCBtp)
           deallocate(BCBtp)
        enddo
        lcblkb(1,nelblb+1) = iel

c
c.... return
c
        return
c
c.... end of file error handling
c
 911    call error ('genbcb  ','end file',igeom)
c
1000    format(a80,//,
     &  ' B o u n d a r y   E l e m e n t   C o n n e c t i v i t y',//,
     &  '   Elem   BC codes',/,
     &  '  Number  C P V H ',5x,27('Node',i1,:,2x))
1100    format(2x,i5,2x,4i2,3x,27i7)
c$$$2000    format(a80,//,
c$$$     &  ' B o u n d a r y   E l e m e n t   B C   D a t a ',//,
c$$$     &  '   Node   ',3x,'mass',/,
c$$$     &  '  Number  ',3x,'flux',6x,'Pressure',6x,'Heat',6x,
c$$$     &  3('Viscous',i1,:,4x))
2100    format(2x,i5,1p,1x,6e12.4)
c
        end




