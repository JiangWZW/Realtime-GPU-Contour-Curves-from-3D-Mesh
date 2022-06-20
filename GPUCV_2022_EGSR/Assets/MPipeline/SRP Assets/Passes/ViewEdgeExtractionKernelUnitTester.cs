using System.Text;

namespace MPipeline.SRP_Assets.Passes
{
    public static class ViewEdgeExtractionKernelUnitTester
    {
        public static bool UnitTest(
            uint[] viewEdgeToSegment, uint[] segmentsToContour, int viewEdgeCount,
            out string testMessage)
        {
            StringBuilder output = new StringBuilder();
            if (viewEdgeCount % 2 != 0)
            {
                output.AppendLine(
                    "#elements = " + viewEdgeCount + 
                    "viewEdgeToSegment buffer should have even number of elements.");
                testMessage = output.ToString();
                return false;
            }

            for (int viewEdgeVert = 0; viewEdgeVert < viewEdgeCount; viewEdgeVert+=2)
            {
                uint contourId0 = segmentsToContour[viewEdgeToSegment[viewEdgeVert]];
                uint contourId1 = segmentsToContour[viewEdgeToSegment[viewEdgeVert + 1]];

                if (contourId0 != contourId1)
                {
                    output.AppendLine("Inconsistent contour found between verts on ViewEdge #" +
                                      viewEdgeVert / 2 + ".");
                    testMessage = output.ToString();
                    return false;
                }
            }
            
            testMessage = output.ToString();
            return true;
        }
    }
}