! Forward part of travel time tomography
! 
! Use strct.f90 and linklist.f90 modules.
! 
! The program includes 3 subroutines:
! cacut:
!       Solve Eikonal equation by using FMM, export travel times in study
!       area, ray paths and Frechet direviative matrix.
! march1:
!       1st order solver of FMM.
! march2:
!       2nd order solver of FMM.
!
!
! Input parameter file: fmm_synt.inp
! Output: traveltime.txt 
!         raypath
! Method:
! Ray tracing: Fast Marching method with 1st order and 2nd order.
! 
!----------------------------------------------------------------

program fmm_fw_regul2tprl

! Main program starts here
!
!--------------------------Paramters---------------------------------------
! 
! source, receiver: 
!       Sources and receivers
! v: 
!       Input velocity model (adaptive nodes' coordinates and velocities)
! g:
!       "G" in Gm=d.
! gnsum, gnavr, gnmax:
!       Sum, average and max of gn
! dx, dy: 
!       Grid spacing for FMM.
! minx, maxx, miny, maxy: 
!       The boundaries of study area.
! start, finish: 
!       Start time and finish time of the program.
! rfxrg, rfyrg: 
!       The range for refined area.
! rfxint, rfyint: 
!       dx(or dy)/rfxint(or rfyint) = grid spacing of refined area
! xtemp, ytemp, veltemp:
!       Temporary storage of x, y and vel in reading previous nodes into
!       velocity nodes linklist.
! stemp:
!       Slowness of newly added nodes.
! thrshd0, thrshd1, thrshd2:
!       The upper bound of total number of adaptive nodes; the threshold of 
!       deleting nodes; and the threshold of adding nodes.
! hwnodenum:
!       The numbers of nodes which are used to add new nodes.
! hwnum, hwmax:
!       The total number of "hwndenum"; the upper bound of "hwnum".
! newndnum:
!       The total number of newly added nodes.
! edgenode:
!       The nodes on the edge, however, has few ray pass by, will not
!       count in inversion.
! ns, is, nr, ir:
!       The total number of sources and receivers, and the counts.
! nt:
!       The total number of travel times been calculated.
! vnum: 
!       Number of adaptive nodes.
! gridtype: 
!       1. Regular grids; 2. Trianglation grids.
! imethod:
!       1. 1st order FMM; 2. 2nd order FMM.
! icoord:
!       1. Cartesian coordinate; 2. Spherical coordinate.
! iv:
!       Count for reading adaptive nodes.
! idmax, immax:
!       The total number of data; the number of velocity model nodes.
! errormem:
!       The status of allocate memory to the members of velocity nodes linklist.
! date, time:
!       Date and time when program runs.
! sourcefile
!       Source file name.
! receiverfile
!       Receiver file name
! velfile
!       adaptive nodes file name
!
!--------------------------------------------------------------------------


use strct
implicit none
type(srstrct3d) :: source(maxsource3d)
type(rcstrct3d) :: receiver(maxdata3d)
type(rcstrct3d) :: preceiver(maxevn3d)
type(tstrct3d) :: node(maxgrid3d)
type(tstrct) :: topoxy(maxgrid)
real(kind=8) :: topoz(maxgrid)
real(kind=8) :: layer(maxgrd1d,3)
real(kind=8) :: dx,dy,dz
real(kind=8) :: minx,maxx
real(kind=8) :: miny,maxy
real(kind=8) :: minz,maxz
real(kind=8) :: tpminx,tpmaxx
real(kind=8) :: tpminy,tpmaxy
real(kind=8) :: topozbtm
real(kind=8) :: start,mid,finish
real(kind=8) :: rfxrg,rfyrg,rfzrg
real(kind=8) :: rfxint,rfyint,rfzint
real(kind=8) :: vair,tempv
real(kind=8) :: tmpt,tmpy,tmpx,tmpz
integer :: nl(3)
integer :: evnid(maxdata3d),ttlevn
integer :: pevnid(maxevn3d)
integer :: tpxnum,tpynum
integer :: edgenode
integer :: ns,is,ir
integer :: nt
integer :: nnode
integer :: imethod
integer :: icoord
integer :: iv
integer :: date(3)
integer :: time(3)
integer :: ndata
integer :: nrcver(maxsource3d)
integer :: evnum(maxdata3d)
integer :: pevnum(maxevn3d)
integer :: irstart
character(len=10) :: tmpstn
character(len=10) :: sourcenum
character(len=70) :: datafile
character(len=70) :: tpfile
character(len=70) :: nodefile
character(len=70) :: fdfname(maxsource3d)
character(len=70) :: tfname(maxsource3d)
character(len=70) :: errfname(maxsource3d)
character(len=70) :: tpsrname(maxsource3d)
character(len=70) :: pfname(maxsource3d)


interface
    subroutine cacut(isr,source,receiver,evnid,ttlevn,evnum,node,nnode,nr,nl,layer,&
      &dx,dy,dz,minx,maxx,miny,maxy,minz,maxz,ttlgnum,rfxint,rfyint,rfzint,&
      &rfxrg,rfyrg,rfzrg,tpminx,tpmaxx,tpminy,tpmaxy,tpxnum,tpynum,topozbtm,&
      &topoxy,topoz,vair,imethod,icoodnt)
        use strct
        use fmarch
        implicit none
        type(srstrct3d) :: source
        type(rcstrct3d) :: receiver(maxevn3d)
        type(tstrct3d),target :: node(maxgrid3d)
        type(tstrct) :: topoxy(maxgrid)
        real(kind=8) :: layer(maxgrd1d,3)
        real(kind=8) :: topoz(maxgrid)
        real(kind=8) :: dx,dy,dz
        real(kind=8) :: minx,maxx,miny,maxy,minz,maxz
        real(kind=8) :: rfxint,rfyint,rfzint,rfxrg,rfyrg,rfzrg
        real(kind=8) :: tpminx,tpmaxx,tpminy,tpmaxy,topozbtm
        real(kind=8) :: vair
        integer :: evnum(maxevn3d),nl(3)
		integer :: evnid(maxevn3d),ttlevn
        integer :: isr,nnode,nr,ttlgnum,tpxnum,tpynum,imethod,icoodnt
    end subroutine
end interface

call cpu_time(start)
call idate(date)
call itime(time)
write(*,2000)date,time
2000 format('Date: ',i2.2,'/',i2.2,'/',i4.4,'; Time: ',&
& i2.2,':',i2.2,':',i2.2)


! Read parameters.
!-----------------------------------------------------------------------
open(21,file='fmm_fw_regul2tprl.inp',status='old')
read(21,*)datafile
read(21,*)nodefile
read(21,*)ns
read(21,*)dx,dy,dz
read(21,*)rfxint,rfyint,rfzint
read(21,*)rfxrg,rfyrg,rfzrg
read(21,*)minx,maxx
read(21,*)miny,maxy
read(21,*)minz,maxz
read(21,*)imethod
read(21,*)icoord
read(21,*)tpfile
read(21,*)tpminx,tpmaxx
read(21,*)tpminy,tpmaxy
read(21,*)tpxnum,tpynum
read(21,*)topozbtm
read(21,*)vair
close(21)

! Read adaptive node file
open(23,file=nodefile,status='old')
read(23,*)nnode,nl(1),nl(2),nl(3)
if(nnode .gt. maxgrid3d)then
    write(*,*)"Number of input velocity number larger than maxgrid3d!"
    write(*,*)"Check the parameter (maxgrid3d) in strct.f90!"
    stop
else if(nnode .le. 4)then
    write(*,*)"Number of input velocity is less than 4!"
    write(*,*)"4 is the minumum number for interpolation!"
    stop
end if
read(23,*)edgenode
do iv=1,nnode
    read(23,*)node(iv)%x,node(iv)%y,node(iv)%z,tempv
    node(iv)%t=1.0d0/tempv
    node(iv)%dxx=0d0
    node(iv)%num=iv
    node(iv)%stat=0
end do
close(23)

do iv=1,nl(1)
    ir=iv
    layer(iv,1)=node(ir)%x
end do

do iv=1,nl(2)
    ir=(iv-1)*nl(1)+1
    layer(iv,2)=node(ir)%y
end do

do iv=1,nl(3)
    ir=(iv-1)*nl(1)*nl(2)+1
    layer(iv,3)=node(ir)%z
end do


! Read topography data
open(27,file=tpfile,status='old')
do iv=1,tpxnum*tpynum
    read(27,*)topoxy(iv)%x,topoxy(iv)%y,topoz(iv)
    topoxy(iv)%num=iv
end do
close(27)


!-----------------------------------------------------------------------

open(22,file=datafile,status='old')
ndata=0
ttlevn=0
do is=1,ns
    read(22,*)nrcver(is)
    read(22,*)tmpstn,source(is)%x,source(is)%y,source(is)%z
    if((source(is)%x .gt. maxx) .or. &
      &(source(is)%x .lt. minx) .or. &
      &(source(is)%y .gt. maxy) .or. &
      &(source(is)%y .lt. miny) .or. &
      &(source(is)%z .gt. maxz) .or. &
      &(source(is)%z .lt. minz))then
        write(*,*)"Number ",is," source is outside study area!!"
        write(*,*)"Coordinates: ",source(is)
        stop
    end if
    do ir=1,nrcver(is)
        ndata=ndata+1
        read(22,*)tmpt,tmpx,tmpy,tmpz,evnid(ndata),receiver(ndata)%x,&
        &receiver(ndata)%y,receiver(ndata)%z
        evnum(ndata)=ndata
        if(evnid(ndata) .gt. ttlevn)then
            ttlevn=evnid(ndata)
        end if
        if((receiver(ndata)%x .gt. maxx) .or. &
          &(receiver(ndata)%x .lt. minx) .or. &
          &(receiver(ndata)%y .gt. maxy) .or. &
          &(receiver(ndata)%y .lt. miny) .or. &
          &(receiver(ndata)%z .gt. maxz) .or. &
          &(receiver(ndata)%z .lt. minz))then
            write(*,*)"Number ",ndata," receiver is outside study area!!"
            write(*,*)"Coordinates: ",receiver(ndata)
            stop
        end if
    end do
end do
close(22)

! Calcu traveltimes, ray paths and Frechet derivative
!----------------------------------------------------------------------

do is=1,ns
    if(is .eq. 1)then
        irstart=1
    else
        irstart=irstart+nrcver(is-1)
    end if

    do ir=1,nrcver(is)
        preceiver(ir)=receiver(irstart+ir-1)
        pevnid(ir)=evnid(irstart+ir-1)
        pevnum(ir)=evnum(irstart+ir-1)
    end do

    call cacut(is,source(is),preceiver,pevnid,ttlevn,pevnum,node,nnode,&
               &nrcver(is),nl,layer,dx,dy,dz,&
               &minx,maxx,miny,maxy,minz,maxz,nt,rfxint,rfyint,rfzint,&
               &rfxrg,rfyrg,rfzrg,tpminx,tpmaxx,tpminy,tpmaxy,tpxnum,&
               &tpynum,topozbtm,topoxy,topoz,vair,imethod,icoord)
!    call system('cp source00001.out rename.out')
!    call rename('source00001.out','rename.out')
    write(*,*)"source",is,"has finished."
    write(*,*)nt,"grids has been caculated."
end do

!-------------------------------------------------------------------------

call cpu_time(mid)
write(*,2001)start,mid,(mid-start)/6.0d1

! Merge tbyfd files and calculated t files.
do is=1,ns
write(sourcenum,2005)is
2005 format(i5.5)
!tbyfdname(is)="tbyfd"//trim(sourcenum)//".txt"
    tfname(is)="t"//trim(sourcenum)//".txt"
    errfname(is)="err"//trim(sourcenum)//".txt"
    fdfname(is)="fd"//trim(sourcenum)//".dat"
    tpsrname(is)="source"//trim(sourcenum)//".dat"
    pfname(is)="path"//trim(sourcenum)//".dat"
end do

!call mergefile(tbyfdname,ns,"tbyfd.txt",0)
call mergefile(tfname,ns,"t.txt",0)
call mergefile(errfname,ns,"errt.txt",0)
call mergebf(fdfname,ns,16,"fd.dat",0)
!call mergebf(tpsrname,ns,60,"tsource.dat",0)
call mergebf(pfname,ns,24,"paths.dat",0)


call idate(date)
call itime(time)
write(*,2000)date,time

call cpu_time(finish)
write(*,2001)start,finish,(finish-start)/6.0d1
2001 format('start: ',f8.4,'; finish: ',f16.4,&
    &'; Time consume: ',f16.4,' min.')

stop

end


!----------------------------------------------------------------------------
!---------------Main program ends here---------------------------------------
!----------------------------------------------------------------------------


!############################################################################



!---------------------------------------------------------------------------
!This subroutine caculate travel time for each grid.
!--------------------------------------------------------------------------
subroutine cacut(isr,source,receiver,evnid,ttlevn,evnum,node,nnode,nr,nl,layer,&
  &dx,dy,dz,minx,maxx,miny,maxy,minz,maxz,ttlgnum,rfxint,rfyint,rfzint,&
  &rfxrg,rfyrg,rfzrg,tpminx,tpmaxx,tpminy,tpmaxy,tpxnum,tpynum,topozbtm,&
  &topoxy,topoz,vair,imethod,icoodnt)

!
!--------------------------Paramters---------------------------------------
! rcenter: 
!       The center point of refined area.
! source, receiver: 
!       Sources and receivers
! path:
!       The discrete nodes on the ray path.
! vorig: 
!       Input velocity model (adaptive nodes' coordinates and velocities)
! prv:
!       Pointers which have 4 elements, are used to locate the receivers and
!       calculate the travel time of receiver by bilinear interpolation.
! travelt:
!       Travel time and coordinates of FMM nodes.
! rtravelt:
!       Travel time and coordinates of the nodes in refined area.
! ptravelt:
!       Pointers are used to store the alive points in FMM.
! rptravelt:
!       Pointers are used to store the live points in refined area.
! nb_head:
!       The head of linklist which are used to store narrow band nodes.
! nb_travelt:
!       The last member of narrow band linklist, which are used to add new
!       narrow band nodes into linklist.
! nb_temp:
!       The pointer is used to search the narrow band linklist, finding alive
!       node.
! ptemp:
!       Pointer is used to sort the initial travel time around the source.       
! v:
!       Velocities of FMM nodes.
! rv:
!       Velocities of the FMM refined nodes.
! rvtemp:
!       Slowness of FMM nodes or FMM refined nodes from interpolation.
! dxx, dyy
!       Grid spacing of FMM in km unit.
! rdxx, rdyy
!       Grid spacing of FMM refined area in km unit.
! dx, dy: 
!       Grid spacing for FMM in degree.
! rdx, rdy:
!       Grid spacing for FMM refined area in degree.
! minx, maxx, miny, maxy: 
!       The boundaries of study area.
! rminx, rmaxx, rminy, rmaxy: 
!       The boundaries of refined area.
! tempt:
!       Temporary store of travel time in searching narrow band linklist.
! rfxrg, rfyrg: 
!       The range for refined area.
! rfrg:
!       Four boundaries of refined area.
! rfxint, rfyint: 
!       dx(or dy)/rfxint(or rfyint) = grid spacing of refined area
! tempara1, temprara2:
!       Parameters (x, y direction) are used to test whether the wave front 
!       arrives the boundaries of refined area.
!       Check whether the FMM outter node is same as refined node.
! dxv, dyv:
!       Valid only when gridtype = 1, used in subroutine "frech_regular".
! temptt:
!       Verify travel times by calculated frechet derivative.
! nbnode:
!       The new narrow band node updated by subroutine "march2".
! nbnum, inb:
!       The total number of new narrow band node. Count the new narrow band
!       nodes in adding nodes to linklist "nb". 
! gridtype: 
!       1. Regular grids; 2. Trianglation grids.
! edgenode:
!       The nodes on the edge, however, has few ray pass by, will not
!       count in inversion.
! gxnum, gynum
!       Valid only when gridtype = 1, used in subroutine "frech_regular".
! vnum: 
!       Number of adaptive nodes.
! samet:
!       Store the numbers of FMM nodes who have the same travel time in updating
!       alive nodes.
! imethod:
!       1. 1st order FMM; 2. 2nd order FMM.
! icoordnt:
!       1. Cartesian coordinate; 2. Spherical coordinate.
! ist:
!       Counter of updating living nodes with same travel time.
! iist:
!       Count ist in loop.
! minxl, maxxl, minyl, maxyl:
!       Integers of boundaries of study area, used in calculating total number
!       of FMM nodes.
! rminxl, rmaxxl, rminyl, rmaxyl:
!       Integers of boundaries of refined area, used in calculating total number
!       of FMM refined nodes.
! xnum, ynum
!       The number of FMM nodes in x and y directions.
! rxnum, rynum
!       The number of FMM refined nodes in x and y directions.
! ttlgnum, rttlgnum:
!       Total numbers of FMM nodes and FMM refined nodes.
! rcnum:
!       The number of center node in FMM refined area.
! gnum:
!       Used in insert refined node value into outter node.
! rgnum:
!       Used in initializing the travel times around the source.
! ig:
!       Counter of FMM nodes and velocities of refined nodes.
! iv:
!       Counter of velocities of FMM nodes.
! ip, iip, rip:
!       Counter of FMM alive nodes, counter of "ip" and "rip",  counter of living
!       nodes of refined area.
! ix, iy:
!       Used in initializing the travel times around the source.
! itempt:
!       Used in find alive grid.
! isr:
!       Input source's number.
! nr, ir:
!       The total number of receivers, and the counter.
! ipth, iipth:
!       The total number of nodes of one ray path, and the counter.
! iipnum:
!       The number of new alive nodes, used for updating the travel times of 
!       new narrow band nodes.
! errormem:
!       Status of allocate memory.
! sourcenum:
!       Character format of source number.
! tfilename:
!       Output travel time file of one source.
! pathfname:
!       Output path file name
! errfname:
!       If the travel time of old alive node is greater than new one, the
!       results will be written in this file
!
!--------------------------------------------------------------------------


use strct
use fmarch
implicit none
type(srstrct3d) :: rcenter
type(srstrct3d) :: source
type(rcstrct3d) :: receiver(maxevn3d)
type(srstrct3d) :: path(maxpathnode3d)
type(tstrct3d), target :: node(maxgrid3d)
type(pstrct3d), pointer :: prv(:)
type(tstrct3d), target :: travelt(maxgrid3d)
type(tstrct3d), target :: rtravelt(maxgrid3d)
type(pstrct3d), pointer :: ptravelt(:)
type(pstrct3d), pointer :: prtravelt(:)
type(pstrct3d), pointer :: ptemp
type(tstrct) :: topoxy(maxgrid)
real(kind=8) :: layer(maxgrd1d,3)
real(kind=8) :: topoz(maxgrid)
real(kind=8) :: s(maxgrid3d)
real(kind=8) :: rs(maxgrid3d)
real(kind=8) :: fd(maxvel3d)
real(kind=8) :: dxx(maxgrd1d,maxgrd1d)
real(kind=8) :: dyy(maxgrd1d),dzz
real(kind=8) :: rdxx(maxgrd1d,maxgrd1d)
real(kind=8) :: rdyy(maxgrd1d),rdzz
real(kind=8) :: ssr,slrc
real(kind=8) :: dx,dy,dz
real(kind=8) :: rdx,rdy,rdz
real(kind=8) :: minx,maxx
real(kind=8) :: miny,maxy
real(kind=8) :: minz,maxz
real(kind=8) :: rminx,rmaxx
real(kind=8) :: rminy,rmaxy
real(kind=8) :: rminz,rmaxz
real(kind=8) :: tpminx,tpmaxx
real(kind=8) :: tpminy,tpmaxy
real(kind=8) :: topozbtm
real(kind=8) :: rfxrg,rfyrg,rfzrg
real(kind=8) :: rfrg(8)
real(kind=8) :: rfxint,rfyint,rfzint
real(kind=8) :: tempara1,tempara2,tempara3
real(kind=8) :: srdist
real(kind=8) :: vair
integer :: nb(maxnbnode3d),nbtail
integer :: tempnbnode(maxnbnode3d),tempnbnum
integer :: nbnode(maxnbnode3d)
integer :: evnum(maxevn3d)
integer :: evnid(maxevn3d),ttlevn
integer :: nl(3),n(8)
integer :: nbnum,inb
integer :: nnode
integer :: imethod
integer :: icoodnt
integer :: ist,iist
integer :: minxl,maxxl
integer :: rminxl,rmaxxl
integer :: minyl,maxyl
integer :: rminyl,rmaxyl
integer :: minzl,maxzl
integer :: rminzl,rmaxzl
integer :: xnum,ynum,znum
integer :: rxnum,rynum,rznum
integer :: ttlgnum,rttlgnum
integer :: rcnum
integer :: gnum,rgnum
integer :: updown
integer :: tpxnum,tpynum
integer :: ig
integer :: ip,iip,rip
integer :: ix,iy,iz
integer :: isr
integer :: nr,ir
integer :: pathrec,fdrec
integer :: ipth,ippth
integer :: iipnum
integer :: i,j,k
character(len=10) :: sourcenum
character(len=70) :: tfilename
character(len=70) :: pathfname
character(len=70) :: errfname
character(len=70) :: fdfname
character(len=70) :: tfname


! initial grid are all far away
travelt%stat=-1
travelt%nbstat=0
rtravelt%stat=-1
rtravelt%nbstat=0

allocate(ptravelt(1:maxgrid3d))
allocate(prtravelt(1:maxgrid3d))
allocate(prv(1:8))

!------------------------------------------------------------------------

minxl=1
maxxl=nint((maxx-minx)/dx)+1
minyl=1
maxyl=nint((maxy-miny)/dy)+1
minzl=1
maxzl=nint((maxz-minz)/dz)+1
xnum=maxxl-minxl+1
ynum=maxyl-minyl+1
znum=maxzl-minzl+1
ttlgnum=xnum*ynum*znum


! Choose coodinate for outter grids.
!--------------------------------------------------------
if(icoodnt .eq. 1)then
    dxx=(pi*radii)*dx/1.8d2
    dyy=(pi*radii)*dy/1.8d2
    dzz=dz
else if(icoodnt .eq. 2)then
    do iz=1,znum
        dyy(iz)=(pi*(radii-(dble(iz)-5.0d-1)*dz))*dy/1.8d2
        do iy=1,ynum
            dxx(iz,iy)=cos((miny+((dble(iy)-5.0d-1)*dy))*pi/1.8d2)&
            &   *pi*(radii-(dble(iz)-5.0d-1)*dz)*dx/1.8d2
        end do
    end do
    dzz=dz
end if

do iz=1,znum
    do iy=1,ynum
        do ix=1,xnum
            ig=(iz-1)*xnum*ynum+(iy-1)*xnum+ix
            travelt(ig)%x=minx+dx*dble(ix-1)
            travelt(ig)%y=miny+dy*dble(iy-1)
            travelt(ig)%z=minz+dz*dble(iz-1)
            travelt(ig)%num=ig
            travelt(ig)%dxx=dxx(iz,iy)
            travelt(ig)%dyy=dyy(iz)
        end do
    end do
end do
            


!---------------------------------------------------------------------


! Determine the center and the range of refine area.
!---------------------------------------------------------------------
rdx=dx/rfxint
rdy=dy/rfyint
rdz=dz/rfzint

! Rcenter is used to set the boundaries of refined area.
rcenter%x=(anint((source%x-minx)/rdx))*rdx+minx
rcenter%y=(anint((source%y-miny)/rdy))*rdy+miny
rcenter%z=(anint((source%z-minz)/rdz))*rdz+minz

! Set up the four boundaries of refined area.
if((rcenter%x-rfxrg) .lt. minx)then
    rminx=minx
else
    rminx=rcenter%x-rfxrg
end if
if((rcenter%x+rfxrg) .gt. maxx)then
    rmaxx=maxx
else
    rmaxx=rcenter%x+rfxrg
end if

if((rcenter%y-rfyrg) .lt. miny)then
    rminy=miny
else
    rminy=rcenter%y-rfyrg
end if
if((rcenter%y+rfyrg) .gt. maxy)then
    rmaxy=maxy
else
    rmaxy=rcenter%y+rfyrg
end if

if((rcenter%z-rfzrg) .lt. minz)then
    rminz=minz
else
    rminz=rcenter%z-rfzrg
end if
if((rcenter%z+rfzrg) .gt. maxz)then
    rmaxz=maxz
else
    rmaxz=rcenter%z+rfzrg
end if

rminxl=nint((rminx-rcenter%x)/rdx)
rmaxxl=nint((rmaxx-rcenter%x)/rdx)
rminyl=nint((rminy-rcenter%y)/rdy)
rmaxyl=nint((rmaxy-rcenter%y)/rdy)
rminzl=nint((rminz-rcenter%z)/rdz)
rmaxzl=nint((rmaxz-rcenter%z)/rdz)

rxnum=rmaxxl-rminxl+1
rynum=rmaxyl-rminyl+1
rznum=rmaxzl-rminzl+1
rttlgnum=rxnum*rynum*rznum
!---------------------------------------------------------------------


! Choose coordinate for refined grids
!--------------------------------------------------------------------
if(icoodnt .eq. 1)then
    rdxx=(pi*radii)*rdx/1.8d2
    rdyy=(pi*radii)*rdy/1.8d2
    rdzz=rdz
else if(icoodnt .eq. 2)then
    do iz=1,rznum
        rdyy(iz)=(pi*(radii-(dble(iz)-5.0d-1)*rdz))*rdy/1.8d2
        do iy=1,rynum
            rdxx(iz,iy)=cos((rminy+((dble(iy)-5.0d-1)*rdy))*pi/1.8d2)&
            &   *pi*(radii-(dble(iz)-5.0d-1)*rdz)*rdx/1.8d2
        end do
    end do
    rdzz=rdz
end if

do iz=1,rznum
    do iy=1,rynum
        do ix=1,rxnum
            ig=(iz-1)*rxnum*rynum+(iy-1)*rxnum+ix
            rtravelt(ig)%x=rminx+rdx*dble(ix-1)
            rtravelt(ig)%y=rminy+rdy*dble(iy-1)
            rtravelt(ig)%z=rminz+rdz*dble(iz-1)
            rtravelt(ig)%num=ig
            rtravelt(ig)%dxx=rdxx(iz,iy)
            rtravelt(ig)%dyy=rdyy(iz)
        end do
    end do
end do
            
!---------------------------------------------------------------------



! Caculate velocity of refined grids with bilinear interpolation method.
!-----------------------------------------------------------------------
!open(230,file='refinevel.txt',status='replace')
!write(230,*)rttlgnum
do ig=1,rttlgnum
    if(rtravelt(ig)%z .gt. topozbtm)then
        call locatcood3d2(n,nl(1),layer(1:maxgrd1d,1),nl(2),&
                        &layer(1:maxgrd1d,2),nl(3),layer(1:maxgrd1d,3),&
                        &rtravelt(ig)%x,rtravelt(ig)%y,rtravelt(ig)%z)
        rs(ig)=trilinear2(node(n(1))%t,node(n(2))%t,&
                         &node(n(3))%t,node(n(4))%t,&
                         &node(n(5))%t,node(n(6))%t,&
                         &node(n(7))%t,node(n(8))%t,&
                         &node(n(1))%x,node(n(1))%y,node(n(1))%z,&
                         &node(n(8))%x,node(n(8))%y,node(n(8))%z,&
                         &rtravelt(ig)%x,rtravelt(ig)%y,rtravelt(ig)%z,&
                         &topoxy,topoz,tpminx,tpmaxx,tpminy,tpmaxy,&
                         &tpxnum,tpynum,vair)
    else
        call psurf(rtravelt(ig)%x,rtravelt(ig)%y,rtravelt(ig)%z,&
                  &topoxy,topoz,updown,tpminx,tpmaxx,tpminy,tpmaxy,&
                  &tpxnum,tpynum)
        if(updown .eq. -1)then
            rs(ig)=1.0d0/vair
        else if(updown .eq. 1)then
            call locatcood3d2(n,nl(1),layer(1:maxgrd1d,1),nl(2),&
                            &layer(1:maxgrd1d,2),nl(3),layer(1:maxgrd1d,3),&
                            &rtravelt(ig)%x,rtravelt(ig)%y,rtravelt(ig)%z)
            rs(ig)=trilinear2(node(n(1))%t,node(n(2))%t,&
                             &node(n(3))%t,node(n(4))%t,&
                             &node(n(5))%t,node(n(6))%t,&
                             &node(n(7))%t,node(n(8))%t,&
                             &node(n(1))%x,node(n(1))%y,node(n(1))%z,&
                             &node(n(8))%x,node(n(8))%y,node(n(8))%z,&
                             &rtravelt(ig)%x,rtravelt(ig)%y,rtravelt(ig)%z,&
                             &topoxy,topoz,tpminx,tpmaxx,tpminy,tpmaxy,&
                             &tpxnum,tpynum,vair)
        else
            write(*,*)"Paramter updown(refined nodes) is not -1,1. Error in subroutine&
                      & psurf in strct.f90."
            stop
        end if
    end if

!    write(230,3000)ig,rv(ig),rtravelt(ig)%x,rtravelt(ig)%y,rtravelt(ig)%z
!3000 format(i6,1x,f10.7,1x,f15.9,1x,f15.9,1x,f15.9)
!    pause
end do
!close(230)
!----------------------------------------------------------------------


! Caculate velocity of source.
!----------------------------------------------------------------------
call locatcood3d2(n,nl(1),layer(1:maxgrd1d,1),nl(2),&
                &layer(1:maxgrd1d,2),nl(3),layer(1:maxgrd1d,3),&
                &source%x,source%y,source%z)
ssr=trilinear2(node(n(1))%t,node(n(2))%t,&
                 &node(n(3))%t,node(n(4))%t,&
                 &node(n(5))%t,node(n(6))%t,&
                 &node(n(7))%t,node(n(8))%t,&
                 &node(n(1))%x,node(n(1))%y,node(n(1))%z,&
                 &node(n(8))%x,node(n(8))%y,node(n(8))%z,&
                 &source%x,source%y,source%z,&
                 &topoxy,topoz,tpminx,tpmaxx,tpminy,tpmaxy,&
                 &tpxnum,tpynum,vair)



! Initial values around the source.
!----------------------------------------------------------------------
rip=0 ! Counter of living grid node 
ist=-1 ! Counter of updating living grid nodes with same travel time
rcnum=1-rminxl-rminyl*rxnum-rminzl*rxnum*rynum
! Initial travel times of 7 nodes around rcenter.
call sphdist(source%x,source%y,source%z,&
  &rtravelt(rcnum)%x,rtravelt(rcnum)%y,&
  &rtravelt(rcnum)%z,srdist)
rtravelt(rcnum)%t=srdist*(ssr+rs(rcnum))/2.0d0
rtravelt(rcnum)%stat=1
rip=rip+1

prtravelt(rip)%p=>rtravelt(rcnum)
ist=ist+1
do ix=-1,1,2
    rgnum=rcnum+ix 
    if((rgnum .ge. 1) .and. (rgnum .le. rttlgnum) .and.&
      &(dble(ix)*(rtravelt(rgnum)%x-rtravelt(rcnum)%x) .gt. 0d0))then
        call sphdist(source%x,source%y,source%z,&
          &rtravelt(rgnum)%x,rtravelt(rgnum)%y,&
          &rtravelt(rgnum)%z,srdist)
        rtravelt(rgnum)%t=srdist*(ssr+rs(rgnum))/2.0d0
        rtravelt(rgnum)%stat=1
        rip=rip+1
        prtravelt(rip)%p=>rtravelt(rgnum)
        ist=ist+1
    end if
end do
do iy=-1,1,2
    rgnum=rcnum+iy*rxnum
    if((rgnum .ge. 1) .and. (rgnum .le. rttlgnum) .and.&
      &(dble(iy)*(rtravelt(rgnum)%y-rtravelt(rcnum)%y) .gt. 0d0))then
        call sphdist(source%x,source%y,source%z,&
          &rtravelt(rgnum)%x,rtravelt(rgnum)%y,&
          &rtravelt(rgnum)%z,srdist)
        rtravelt(rgnum)%t=srdist*(ssr+rs(rgnum))/2.0d0
        rtravelt(rgnum)%stat=1
        rip=rip+1
        prtravelt(rip)%p=>rtravelt(rgnum)
        ist=ist+1
    end if
end do
do iz=-1,1,2
    rgnum=rcnum+iz*rynum*rxnum
    if((rgnum .ge. 1) .and. (rgnum .le. rttlgnum))then
        call sphdist(source%x,source%y,source%z,&
          &rtravelt(rgnum)%x,rtravelt(rgnum)%y,&
          &rtravelt(rgnum)%z,srdist)
        rtravelt(rgnum)%t=srdist*(ssr+rs(rgnum))/2.0d0
        rtravelt(rgnum)%stat=1
        rip=rip+1
        prtravelt(rip)%p=>rtravelt(rgnum)
        ist=ist+1
    end if
end do
!----------------------------------------------------------------------


! Sort the initial values, with bubble sort method.
!----------------------------------------------------------------------
allocate(ptemp)
if(rip .gt. 1)then
    do ix=1,rip-1
        do iy=ix+1,rip
            if(prtravelt(iy)%p%t .lt. prtravelt(ix)%p%t)then
                ptemp%p=>prtravelt(ix)%p
                prtravelt(ix)%p=>prtravelt(iy)%p
                prtravelt(iy)%p=>ptemp%p
            end if
        end do
    end do
end if
deallocate(ptemp)
!---------------------------------------------------------------------        


! Check if the coordinate of outter grid is as same as refined grid. If
! so, assign the value to outter grid.
!---------------------------------------------------------------------
ip=0
do ig=1,rip
    tempara1=prtravelt(ig)%p%x-dx*&
    &   anint(prtravelt(ig)%p%x/dx)
    tempara2=prtravelt(ig)%p%y-dy*&
    &   anint(prtravelt(ig)%p%y/dy)
    tempara3=prtravelt(ig)%p%z-dz*&
    &   anint(prtravelt(ig)%p%z/dz)
    if((abs(tempara1) .lt. 1d-3*rdx) .and.& 
    &  (abs(tempara2) .lt. 1d-3*rdy) .and.&
    &  (abs(tempara3) .lt. 1d-3*rdz))then
       gnum=nint((prtravelt(ig)%p%x-minx)/dx)+1+&
       &    nint((prtravelt(ig)%p%y-miny)/dy)*xnum+&
       &    nint((prtravelt(ig)%p%z-minz)/dz)*xnum*ynum
       travelt(gnum)%t=prtravelt(ig)%p%t
       travelt(gnum)%stat=1
       ip=ip+1
       ptravelt(ip)%p=>travelt(gnum)
    end if
end do
!----------------------------------------------------------------------



! Refined grids caculation begins.
!------------------------------------------------------------------------
! Consider sources closed to the edge, to avoid stopping calculating
! refined grids if wave front arrives at the edge of study area.
rfrg(1)=rcenter%x+rfxrg-rdx/1.0d1
rfrg(2)=rcenter%x-rfxrg+rdx/1.0d1
rfrg(3)=rcenter%y+rfyrg-rdy/1.0d1
rfrg(4)=rcenter%y-rfyrg+rdy/1.0d1
rfrg(5)=rcenter%z+rfzrg-rdz/1.0d1
rfrg(6)=rcenter%z-rfzrg+rdz/1.0d1
i=1
j=1
k=1
nb=0
nbtail=0
do while( (prtravelt(rip)%p%x .lt. rfrg(1)) .and.& 
&         (prtravelt(rip)%p%x .gt. rfrg(2)) .and.&
&         (prtravelt(rip)%p%y .lt. rfrg(3)) .and.&
&         (prtravelt(rip)%p%y .gt. rfrg(4)) .and.&
&         (prtravelt(rip)%p%z .lt. rfrg(5)) .and.&
&         (prtravelt(rip)%p%z .gt. rfrg(6)) )

    i=i+1
    ! Update narrow band grid.
    !----------------------------------------------------------------------
    tempnbnum=0
    do iip=rip-ist,rip
        iipnum=prtravelt(iip)%p%num
        if(imethod .eq. 1)then
            call march1(iipnum,rtravelt,rs,rxnum,rttlgnum,rdzz)
        else if(imethod .eq. 2)then
            j=j+1
            call march2(iipnum,rtravelt,rs,rxnum,rynum,rttlgnum,&
                       &rdzz,nbnode,nbnum)
        else
            write(*,*)"Methods parameter is neither 1 or 2!!"
        end if
        
        ! Add narrow band nodes to tempnbnode
        tempnbnode(tempnbnum+1:tempnbnum+nbnum)=nbnode(1:nbnum)
        tempnbnum=tempnbnum+nbnum
    end do
    
    !----------------------------------------------------------------------
    
    do inb=1,tempnbnum
        if(rtravelt(tempnbnode(inb))%nbstat .eq. 0)then
            nbtail=nbtail+1
            nb(nbtail)=tempnbnode(inb)
            rtravelt(nb(nbtail))%nbstat=nbtail
            rtravelt(nb(nbtail))%stat=0
            call upheap(rtravelt,nb,nbtail)
        else if(rtravelt(tempnbnode(inb))%nbstat .gt. 0)then
            rtravelt(tempnbnode(inb))%stat=0
            call updateheap(rtravelt,nb,rtravelt(tempnbnode(inb))%nbstat,nbtail)
        end if
    end do




    ! Find alive grid, delete the root of heap and its children with same
    ! values as the root.
    !-------------------------------------------------------------------
    ist=0
    prtravelt(rip+1)%p=>rtravelt(nb(1))
    prtravelt(rip+1)%p%stat=1
    prtravelt(rip+1)%p%nbstat=0
    nb(1)=nb(nbtail)
    rtravelt(nb(1))%nbstat=1
    nbtail=nbtail-1
    call downheap(rtravelt,nb,1,nbtail)

    ! Insert refined grid value into outter grid.
    tempara1=prtravelt(rip+1)%p%x-dx*&
    &   anint(prtravelt(rip+1)%p%x/dx)
    tempara2=prtravelt(rip+1)%p%y-dy*&
    &   anint(prtravelt(rip+1)%p%y/dy)
    tempara3=prtravelt(rip+1)%p%z-dz*&
    &   anint(prtravelt(rip+1)%p%z/dz)
    if((abs(tempara1) .lt. 1d-3*rdx) .and.& 
    &  (abs(tempara2) .lt. 1d-3*rdy) .and.&
    &  (abs(tempara3) .lt. 1d-3*rdz))then
        gnum=nint((prtravelt(rip+1)%p%x-minx)/dx)+1+&
        &    nint((prtravelt(rip+1)%p%y-miny)/dy)*xnum+&
        &    nint((prtravelt(rip+1)%p%z-minz)/dz)*xnum*ynum
        travelt(gnum)%t=prtravelt(rip+1)%p%t
        travelt(gnum)%stat=1
        ip=ip+1
        ptravelt(ip)%p=>travelt(gnum)
    end if

    rip=rip+1

    do while(rtravelt(nb(1))%t .eq. prtravelt(rip)%p%t)
        ist=ist+1
        prtravelt(rip+1)%p=>rtravelt(nb(1))
        prtravelt(rip+1)%p%stat=1
        prtravelt(rip+1)%p%nbstat=0
        nb(1)=nb(nbtail)
        rtravelt(nb(1))%nbstat=1
        nbtail=nbtail-1
        call downheap(rtravelt,nb,1,nbtail)
        rip=rip+1
    end do

    if(ist .gt. 0)then
        do iist=1,ist
            iip=rip-iist+1
            prtravelt(iip)%p%stat=1
            tempara1=prtravelt(iip)%p%x-dx*&
            &   anint(prtravelt(iip)%p%x/dx)
            tempara2=prtravelt(iip)%p%y-dy*&
            &   anint(prtravelt(iip)%p%y/dy)
            tempara3=prtravelt(iip)%p%z-dz*&
            &   anint(prtravelt(iip)%p%z/dz)
            if((abs(tempara1) .lt. 1d-3*rdx) .and.& 
            &  (abs(tempara2) .lt. 1d-3*rdy) .and.&
            &  (abs(tempara3) .lt. 1d-3*rdz) )then
                gnum=nint((prtravelt(iip)%p%x-minx)/dx)+1+&
                &    nint((prtravelt(iip)%p%y-miny)/dy)*xnum+&
                &    nint((prtravelt(iip)%p%z-minz)/dz)*xnum*ynum
                travelt(gnum)%t=prtravelt(iip)%p%t
                travelt(gnum)%stat=1
                ip=ip+1
                ptravelt(ip)%p=>travelt(gnum)
            end if
        end do
    end if
    !----------------------------------------------------------------

end do


! Caculate non-refined ereas. Line553
!------------------------------------------------------------------------

ist=ip-1
!open(232,file='vfile.txt')
!write(232,*)ttlgnum
do ig=1,ttlgnum
    if(travelt(ig)%z .gt. topozbtm)then
        call locatcood3d2(n,nl(1),layer(1:maxgrd1d,1),nl(2),&
                        &layer(1:maxgrd1d,2),nl(3),layer(1:maxgrd1d,3),&
                        &travelt(ig)%x,travelt(ig)%y,travelt(ig)%z)
        s(ig)=trilinear2(node(n(1))%t,node(n(2))%t,&
                         &node(n(3))%t,node(n(4))%t,&
                         &node(n(5))%t,node(n(6))%t,&
                         &node(n(7))%t,node(n(8))%t,&
                         &node(n(1))%x,node(n(1))%y,node(n(1))%z,&
                         &node(n(8))%x,node(n(8))%y,node(n(8))%z,&
                         &travelt(ig)%x,travelt(ig)%y,travelt(ig)%z,&
                         &topoxy,topoz,tpminx,tpmaxx,tpminy,tpmaxy,&
                         &tpxnum,tpynum,vair)
    else
        call psurf(travelt(ig)%x,travelt(ig)%y,travelt(ig)%z,&
                  &topoxy,topoz,updown,tpminx,tpmaxx,tpminy,tpmaxy,&
                  &tpxnum,tpynum)
        if(updown .eq. -1)then
            s(ig)=1.0d0/vair
        else if(updown .eq. 1)then
            call locatcood3d2(n,nl(1),layer(1:maxgrd1d,1),nl(2),&
                            &layer(1:maxgrd1d,2),nl(3),layer(1:maxgrd1d,3),&
                            &travelt(ig)%x,travelt(ig)%y,travelt(ig)%z)
            s(ig)=trilinear2(node(n(1))%t,node(n(2))%t,&
                             &node(n(3))%t,node(n(4))%t,&
                             &node(n(5))%t,node(n(6))%t,&
                             &node(n(7))%t,node(n(8))%t,&
                             &node(n(1))%x,node(n(1))%y,node(n(1))%z,&
                             &node(n(8))%x,node(n(8))%y,node(n(8))%z,&
                             &travelt(ig)%x,travelt(ig)%y,travelt(ig)%z,&
                             &topoxy,topoz,tpminx,tpmaxx,tpminy,tpmaxy,&
                             &tpxnum,tpynum,vair)
        else
            write(*,*)"Paramter updown(outter nodes) is not -1,1. Error in subroutine&
                      & psurf in strct.f90."
            stop
        end if
    end if

!    write(232,*)travelt(ig)%x,travelt(ig)%y,travelt(ig)%z,v(ig),ig
end do
!close(232)


i=1
j=1
k=1
nb=0
nbtail=0
!open(233,file='temp_ptravelt.txt')

! Update live, narrow band grid.
!-------------------------------------------------------------------------
do while(ip .lt. ttlgnum)
    i=i+1
    ! Update narrow band grid.
    !-------------------------------------------------------------------------
    tempnbnum=0
    do iip=ip-ist,ip
!        write(233,*)ptravelt(iip)%p
        iipnum=ptravelt(iip)%p%num
        if(imethod .eq. 1)then
            call march1(iipnum,travelt,s,xnum,ttlgnum,dzz)
        else if(imethod .eq. 2)then
            j=j+1
            call march2(iipnum,travelt,s,xnum,ynum,ttlgnum,&
                    &dzz,nbnode,nbnum)
        else
            write(*,*)"Method parameter is neither 1 or 2!!!"
        end if

        ! Add narrow band nodes to tempnbnode
        tempnbnode(tempnbnum+1:tempnbnum+nbnum)=nbnode(1:nbnum)
        tempnbnum=tempnbnum+nbnum
    end do

    ! Add narrow band nodes to nb
    do inb=1,tempnbnum
        if(travelt(tempnbnode(inb))%nbstat .eq. 0)then
            nbtail=nbtail+1
            nb(nbtail)=tempnbnode(inb)
            travelt(nb(nbtail))%nbstat=nbtail
            travelt(nb(nbtail))%stat=0
            call upheap(travelt,nb,nbtail)
        else if(travelt(tempnbnode(inb))%nbstat .gt. 0)then
            travelt(tempnbnode(inb))%stat=0
            call updateheap(travelt,nb,travelt(tempnbnode(inb))%nbstat,nbtail)
        end if
    end do


    !----------------------------------------------------------------------
    
    ! Find alive grid
    !----------------------------------------------------------------------
    ist=0
    ptravelt(ip+1)%p=>travelt(nb(1))
    ptravelt(ip+1)%p%stat=1
    ptravelt(ip+1)%p%nbstat=0
    nb(1)=nb(nbtail)
    travelt(nb(1))%nbstat=1
    nbtail=nbtail-1
    call downheap(travelt,nb,1,nbtail)
    ip=ip+1
    do while((travelt(nb(1))%t .eq. ptravelt(ip)%p%t) .and. &
            &(nbtail .ge. 1))
        ist=ist+1
        ptravelt(ip+1)%p=>travelt(nb(1))
        ptravelt(ip+1)%p%stat=1
        ptravelt(ip+1)%p%nbstat=0
        nb(1)=nb(nbtail)
        travelt(nb(1))%nbstat=1
        nbtail=nbtail-1
        call downheap(travelt,nb,1,nbtail)
        ip=ip+1
    end do


end do
!close(233)
!-------------------------------------------------------------------------



! Find the ray path and frechet derivative
!--------------------------------------------------------------------------

write(sourcenum,1000)isr
pathfname="path"//trim(sourcenum)//".dat"
fdfname="fd"//trim(sourcenum)//".dat"
tfname="t"//trim(sourcenum)//".txt"
!tbyfdname="tbyfd"//trim(sourcenum)//".txt"
open(101,file=pathfname,status='replace',form='unformatted',&
    &access='direct',recl=24)
open(105,file=fdfname,status='replace',form='unformatted',&
    &access='direct',recl=16)
open(110,file=tfname,status='replace')
pathrec=0
fdrec=0
do ir=1,nr
    ! Calculate travel time for one receiver
    call localcood3d(receiver(ir)%x,receiver(ir)%y,receiver(ir)%z,&
                  &travelt,prv,dx,dy,dz,minx,maxx,miny,maxy,minz,&
                  &maxz,xnum,ynum,znum)
    receiver(ir)%t=trilinear(prv(1)%p%t,prv(2)%p%t,prv(3)%p%t,&
                   &prv(4)%p%t,prv(5)%p%t,prv(6)%p%t,prv(7)%p%t,&
                   &prv(8)%p%t,prv(1)%p%x,prv(1)%p%y,prv(1)%p%z,&
                   &prv(8)%p%x,prv(8)%p%y,prv(8)%p%z,receiver(ir)%x,&
                   &receiver(ir)%y,receiver(ir)%z,1)
    
    write(110,*)receiver(ir)%t,receiver(ir)%x,receiver(ir)%y,receiver(ir)%z


    ! Calculate ray path for one receiver-source. Travel times grid is
    ! regular grid. Bilinear interpolation will be used.
    call raypath3d(travelt,receiver(ir),source,path,ipth,dx,dy,dz,minx,&
                   &maxx,miny,maxy,minz,maxz,xnum,ynum,znum)

    ! Calculate frechet derivative matrix.
    call psurf(receiver(ir)%x,receiver(ir)%y,receiver(ir)%z,&
              &topoxy,topoz,updown,tpminx,tpmaxx,tpminy,tpmaxy,&
              &tpxnum,tpynum)
    if(updown .eq. -1)then
        write(*,*)"The event is above the earth surface!!!"
        write(*,*)receiver(ir)%x,receiver(ir)%y,receiver(ir)%z
        stop
    end if
    call locatcood3d2(n,nl(1),layer(1:maxgrd1d,1),nl(2),&
                    &layer(1:maxgrd1d,2),nl(3),layer(1:maxgrd1d,3),&
                    &receiver(ir)%x,receiver(ir)%y,receiver(ir)%z)
    slrc=trilinear2(node(n(1))%t,node(n(2))%t,&
                   &node(n(3))%t,node(n(4))%t,&
                   &node(n(5))%t,node(n(6))%t,&
                   &node(n(7))%t,node(n(8))%t,&
                   &node(n(1))%x,node(n(1))%y,node(n(1))%z,&
                   &node(n(8))%x,node(n(8))%y,node(n(8))%z,&
                   &receiver(ir)%x,receiver(ir)%y,receiver(ir)%z,&
                   &topoxy,topoz,tpminx,tpmaxx,tpminy,tpmaxy,&
                   &tpxnum,tpynum,vair)
    call frech_reg2sph3d2rl(node,path,ipth,evnid(ir),ttlevn,slrc,fd,&
                           &layer,nl,topoxy,topoz,tpminx,tpmaxx,&
                           &tpminy,tpmaxy,tpxnum,tpynum)

    ! Verify the travel time by frechet derivative.
    ! Outputs are non-zero entries of fd, row number or id (evnum(ir)), 
    ! column number or im (ippth).
    do ippth=1,nnode+ttlevn*4
        if(fd(ippth) .ne. 0d0)then
            fdrec=fdrec+1
            write(105,rec=fdrec)fd(ippth),evnum(ir),ippth
        end if
    end do

    pathrec=pathrec+1
    write(101,rec=pathrec)ipth
    do ippth=1,ipth
        pathrec=pathrec+1
        write(101,rec=pathrec)path(ippth)
    end do

end do

close(101)
close(105)
close(110)
!------------------------------------------------------------------------


! Write travel time in files.
!------------------------------------------------------------------------
write(sourcenum,1000)isr
1000 format(i5.5)
tfilename="source"//trim(sourcenum)//".dat"
errfname="err"//trim(sourcenum)//".txt"

!open(102,file=tfilename,status='replace',form='unformatted',&
!    &access='direct',recl=60)
open(108,file=errfname,status='replace')
do ist=1,ip-1
    if(ptravelt(ist)%p%t .gt. ptravelt(ist+1)%p%t)then
        write(108,*)ist+1,ptravelt(ist+1)%p,&
        &   ptravelt(ist+1)%p%t-ptravelt(ist)%p%t
    end if
end do
!do ist=1,ip
!    write(102,rec=ist)ptravelt(ist)%p
!    write(103,1001)travelt(ist)
!1001 format(1x,f16.12,1x,f16.12,1x,f16.12,1x,f16.12,1x,f16.12,1x,f16.12,1x,i6.6,1x,i1)
!end do
!close(102)    
!close(103)
close(108)
!-------------------------------------------------------------------------


deallocate(ptravelt)
deallocate(prtravelt)
deallocate(prv)
end subroutine cacut

!----------------------------------------------------------------------------
!---------------Subroutine cacut ends here-----------------------------------
!----------------------------------------------------------------------------

