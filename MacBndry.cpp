//
// $Id: MacBndry.cpp,v 1.9 1998-06-08 15:51:15 lijewski Exp $
//

#include <LO_BCTYPES.H>
#include <MacBndry.H>

void
MacBndry::setBndryConds (const BCRec& phys_bc,
                         IntVect&     ratio)
{
    //
    // ALL BCLOC VALUES ARE NOW DEFINED AS A LENGTH IN PHYSICAL
    // DIMENSIONS *RELATIVE* TO THE FACE, NOT IN ABSOLUTE PHYSICAL SPACE
    //
    const BoxArray& grids      = boxes();
    const int comp             = 0;
    const int ngrds            = grids.length();
    const Real* dx             = geom.CellSize();
    const Box& domain          = geom.Domain();
    const RealBox& prob_domain = geom.ProbDomain();

    for (OrientationIter fi; fi; ++fi)
    {
        Array<Real>& bloc                = bcloc[fi()];
        Array< Array<BoundCond> >& bctag = bcond[fi()];

        int dir    = fi().coordDir();
        Real delta = dx[dir]*ratio[dir];
        int p_bc   = (fi().isLow() ? phys_bc.lo(dir) : phys_bc.hi(dir));

        for (int i = 0; i < ngrds; i++)
        {
            const Box& grd = grids[i];
            int faceindx   = grd[fi()] + (fi().isLow() ? 0 : 1);

            if (domain[fi()] == grd[fi()] && !geom.isPeriodic(dir))
            {
                //
                // All physical bc values are located on face.
                //
                bctag[i][comp] = (p_bc == Outflow) ? LO_DIRICHLET : LO_NEUMANN;
                bloc[i]        = 0;
            }
            else
            {
                //
                // Internal bndry.
                //
                bctag[i][comp] = LO_DIRICHLET;
		bloc[i] = 0.5*delta;
            }
        }
    }
}
