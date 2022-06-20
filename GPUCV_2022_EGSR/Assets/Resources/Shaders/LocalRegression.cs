using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

namespace Assets.Resources.Shaders
{
    public static class LocalRegression
    {
        private static void GaussianWeight(
            in int kernelRadius, 
            in double sigma, 
            out List<double> gaussian
        )
        {
            double normalizeFactor = 1.0 / (sigma * math.sqrt(2.0 * math.PI));
            gaussian = new List<double>();
            double sum = 0;
            for (int i = 0; i <= kernelRadius; ++i)
            {
                double x = (double) i;
                gaussian.Add(
                    normalizeFactor *
                    math.exp(-0.5 * (x * x) / (sigma * sigma))
                );
                sum += ((i == 0) ? 1 : 2) * gaussian[i];
            }

            for (int i = 0; i <= kernelRadius; i++)
            {
                gaussian[i] /= sum;
            }
        }

        public static float[] ComputeQuadraticRegressionKernel(
            int kernelRadius, double sigma)
        {

            // (2N + 1) coeffs for poly regression of order N
            const int numCoeffs = 2 * 2 + 1;

            GaussianWeight(kernelRadius, sigma, out List<double> weight);

            List<double> coeffs = new List<double>();
            for (int j = 0; j < numCoeffs; ++j)
            {
                coeffs.Add(0);
            }

            for (int xi = -kernelRadius; xi <= kernelRadius; xi++)
            {
                double xIPowJ = 1;
                for (int j = 0; j < numCoeffs; j++)
                {
                    coeffs[j] += weight[math.abs(xi)] * xIPowJ;
                    xIPowJ *= xi;
                }
            }
            
            double3x3 v = new double3x3(
                coeffs[0], coeffs[1], coeffs[2], // row-major
                coeffs[1], coeffs[2], coeffs[3],
                coeffs[2], coeffs[3], coeffs[4]
            );
            
            v = math.inverse(v);
            
            // Inverse matrix of symmetric matrix is
            // still symmetric.
            // we need row0, just take col0.
            double3 gamma = v.c0; // only parameter of order 0 is needed
            float[] kernel = new float[kernelRadius * 2 + 1];
            
            for (int i = -kernelRadius; i <= kernelRadius; i++)
            {
                double xi = i;
                kernel[i + kernelRadius] = (float)
                    (weight[math.abs(i)] * math.dot(gamma, new double3(1, xi, xi * xi)));
            }

            return kernel;
        }
    }
}