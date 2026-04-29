/* ADI program */

#include <algorithm>
#include <chrono>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>

int main(int argc, char *argv[])
{
    const double maxeps = 0.01;
    const int itmax = 10;

    int nx = 256, ny = 256, nz = 256;
    switch (argc)
    {
    case 2: nx = ny = nz = std::stoi(argv[1]); break;
    case 4:
        nx = std::stoi(argv[1]);
        ny = std::stoi(argv[2]);
        nz = std::stoi(argv[3]);
        break;
    default: break;
    }

    auto IDX = [&](int i, int j, int k) { return i * ny * nz + j * nz + k; };

    std::vector<double> a(nx * ny * nz);

    auto start = std::chrono::steady_clock::now();

    for (int i = 0; i < nx; i++)
        for (int j = 0; j < ny; j++)
            for (int k = 0; k < nz; k++)
                a[IDX(i, j, k)] = (k == 0 || k == nz - 1 || j == 0 || j == ny - 1 || i == 0 || i == nx - 1)
                    ? 10.0 * i / (nx - 1) + 10.0 * j / (ny - 1) + 10.0 * k / (nz - 1)
                    : 0.0;

    double eps = 0.0;
    int it;
    for (it = 1; it <= itmax; it++)
    {
        eps = 0.0;
        for (int i = 1; i < nx - 1; i++)
            for (int j = 1; j < ny - 1; j++)
                for (int k = 1; k < nz - 1; k++)
                    a[IDX(i, j, k)] = (a[IDX(i - 1, j, k)] + a[IDX(i + 1, j, k)]) / 2;

        for (int i = 1; i < nx - 1; i++)
            for (int j = 1; j < ny - 1; j++)
                for (int k = 1; k < nz - 1; k++)
                    a[IDX(i, j, k)] = (a[IDX(i, j - 1, k)] + a[IDX(i, j + 1, k)]) / 2;

        for (int i = 1; i < nx - 1; i++)
            for (int j = 1; j < ny - 1; j++)
                for (int k = 1; k < nz - 1; k++)
                {
                    double tmp1 = (a[IDX(i, j, k - 1)] + a[IDX(i, j, k + 1)]) / 2;
                    eps = std::max(eps, std::abs(a[IDX(i, j, k)] - tmp1));
                    a[IDX(i, j, k)] = tmp1;
                }

        std::cout << " IT = " << std::setw(4) << it
                  << "   EPS = " << std::scientific << std::setprecision(7) << eps << "\n";
        if (eps < maxeps)
            break;
    }

    auto end = std::chrono::steady_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    std::cout << std::resetiosflags(std::ios::floatfield)
              << " ADI Benchmark Completed.\n"
              << " Size            = " << nx << " x " << ny << " x " << nz << "\n"
              << " Iterations      =       " << itmax << "\n"
              << " Time in seconds =       " << std::fixed << std::setprecision(2) << elapsed << "\n"
              << " Operation type  =   double precision\n"
              << " Verification    =       "
              << (std::abs(eps - 0.07249074) < 1e-6 ? "SUCCESSFUL" : "UNSUCCESSFUL") << "\n"
              << " END OF ADI Benchmark\n";

    std::ofstream out("adi3d_cpu_out", std::ios::binary);
    out.write(reinterpret_cast<const char *>(a.data()),
              static_cast<std::streamsize>(nx * ny * nz * sizeof(double)));

    return 0;
}

