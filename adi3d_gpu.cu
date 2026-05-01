/* ADI program */

#include <chrono>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <vector>
#include <thrust/device_vector.h>
#include <thrust/functional.h>
#include <thrust/reduce.h>

// реализация транспозиции --- https://oz.nthu.edu.tw/~d947207/index_3Ddata.htm

static const int BLOCK = 16;

__global__ void xyz2zxy_kernel(double * __restrict__ Y, const double * __restrict__ X,
    int nx, int ny, int nz, int Gy, int Gz, float rGy, float rGz, int k2)
{
    __shared__ double tile[BLOCK][BLOCK + 1];
    int s1 = __float2int_rz(floorf(__uint2float_rz(blockIdx.x) * rGz));
    int t1 = blockIdx.x - Gz * s1;
    int s2 = __float2int_rz(floorf(__uint2float_rz(blockIdx.y) * rGy));
    int t2 = blockIdx.y - Gy * s2;
    int i  = s2 * k2 + s1;
    int j  = t2 * BLOCK + threadIdx.y;
    int k  = t1 * BLOCK + threadIdx.x;
    if (i < nx && j < ny && k < nz)
        tile[threadIdx.y][threadIdx.x] = X[i * ny * nz + j * nz + k];
    __syncthreads();
    j = t2 * BLOCK + threadIdx.x;
    k = t1 * BLOCK + threadIdx.y;
    if (i < nx && j < ny && k < nz)
        Y[k * nx * ny + i * ny + j] = tile[threadIdx.x][threadIdx.y];
}

__global__ void zxy2xyz_kernel(double * __restrict__ X, const double * __restrict__ Y,
    int nx, int ny, int nz, int Gy, int Gz, float rGy, float rGz, int k2)
{
    __shared__ double tile[BLOCK][BLOCK + 1];
    int s1 = __float2int_rz(floorf(__uint2float_rz(blockIdx.x) * rGz));
    int t1 = blockIdx.x - Gz * s1;
    int s2 = __float2int_rz(floorf(__uint2float_rz(blockIdx.y) * rGy));
    int t2 = blockIdx.y - Gy * s2;
    int i  = s2 * k2 + s1;
    int j  = t2 * BLOCK + threadIdx.x;
    int k  = t1 * BLOCK + threadIdx.y;
    if (i < nx && j < ny && k < nz)
        tile[threadIdx.y][threadIdx.x] = Y[k * nx * ny + i * ny + j];
    __syncthreads();
    j = t2 * BLOCK + threadIdx.y;
    k = t1 * BLOCK + threadIdx.x;
    if (i < nx && j < ny && k < nz)
        X[i * ny * nz + j * nz + k] = tile[threadIdx.x][threadIdx.y];
}

void xyz2zxy(double *Y, double *X, int nx, int ny, int nz)
{
    int Gz = (nz + BLOCK - 1) / BLOCK;
    int Gy = (ny + BLOCK - 1) / BLOCK;
    int k1 = (int)floor(sqrt((double)nx)), k2;
    for (; k1 >= 1; k1--) { k2 = (int)ceil((double)nx / k1); if (k1*k2 - nx <= 1) break; }
    k2 = (int)ceil((double)nx / k1);
    const float eps = 1e-5f;
    xyz2zxy_kernel<<<dim3(k2*Gz, k1*Gy), dim3(BLOCK, BLOCK)>>>(Y, X,
        nx, ny, nz, Gy, Gz, (1+eps)/Gy, (1+eps)/Gz, k2);
}

void zxy2xyz(double *Y, double *X, int nx, int ny, int nz)
{
    int Gz = (nz + BLOCK - 1) / BLOCK;
    int Gy = (ny + BLOCK - 1) / BLOCK;
    int k1 = (int)floor(sqrt((double)nx)), k2;
    for (; k1 >= 1; k1--) { k2 = (int)ceil((double)nx / k1); if (k1*k2 - nx <= 1) break; }
    k2 = (int)ceil((double)nx / k1);
    const float eps = 1e-5f;
    zxy2xyz_kernel<<<dim3(k2*Gz, k1*Gy), dim3(BLOCK, BLOCK)>>>(Y, X,
        nx, ny, nz, Gy, Gz, (1+eps)/Gy, (1+eps)/Gz, k2);
}

__global__ void init_kernel(double *a, int nx, int ny, int nz)
{
    int i = blockIdx.z;
    int j = blockIdx.y * blockDim.y + threadIdx.y;
    int k = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= nx || j >= ny || k >= nz) return;
    if (k == 0 || k == nz - 1 || j == 0 || j == ny - 1 || i == 0 || i == nx - 1)
        a[i * ny * nz + j * nz + k] = 10.0 * i / (nx - 1) + 10.0 * j / (ny - 1) + 10.0 * k / (nz - 1);
    else
        a[i * ny * nz + j * nz + k] = 0.0;
}

__global__ void sweep_x_kernel(double *a, int nx, int ny, int nz)
{
    int j = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int k = blockIdx.x * blockDim.x + threadIdx.x + 1;
    if (j >= ny - 1 || k >= nz - 1) return;
    for (int i = 1; i < nx - 1; i++)
        a[i * ny * nz + j * nz + k] =
            (a[(i - 1) * ny * nz + j * nz + k] + a[(i + 1) * ny * nz + j * nz + k]) / 2.0;
}

__global__ void sweep_y_kernel(double *a, int nx, int ny, int nz)
{
    int i = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int k = blockIdx.x * blockDim.x + threadIdx.x + 1;
    if (i >= nx - 1 || k >= nz - 1) return;
    for (int j = 1; j < ny - 1; j++)
        a[i * ny * nz + j * nz + k] =
            (a[i * ny * nz + (j - 1) * nz + k] + a[i * ny * nz + (j + 1) * nz + k]) / 2.0;
}

__global__ void sweep_z_transposed_kernel(double *a, double * __restrict__ row_eps, int nz, int nx, int ny)
{
    int i = blockIdx.y * blockDim.y + threadIdx.y + 1;
    int j = blockIdx.x * blockDim.x + threadIdx.x + 1;
    if (i >= nx - 1 || j >= ny - 1) return;
    double local_eps = 0.0;
    for (int k = 1; k < nz - 1; k++)
    {
        double tmp = (a[(k - 1) * nx * ny + i * ny + j] + a[(k + 1) * nx * ny + i * ny + j]) / 2.0;
        local_eps = fmax(local_eps, fabs(a[k * nx * ny + i * ny + j] - tmp));
        a[k * nx * ny + i * ny + j] = tmp;
    }
    row_eps[(i - 1) * (ny - 2) + (j - 1)] = local_eps;
}

void sweep_x(double *a, int nx, int ny, int nz)
{
    dim3 block(BLOCK, BLOCK);
    dim3 grid((nz - 2 + BLOCK - 1) / BLOCK, (ny - 2 + BLOCK - 1) / BLOCK);
    sweep_x_kernel<<<grid, block>>>(a, nx, ny, nz);
}

void sweep_y(double *a, int nx, int ny, int nz)
{
    dim3 block(BLOCK, BLOCK);
    dim3 grid((nz - 2 + BLOCK - 1) / BLOCK, (nx - 2 + BLOCK - 1) / BLOCK);
    sweep_y_kernel<<<grid, block>>>(a, nx, ny, nz);
}

void sweep_z(double *a, double *buf, double *row_eps, int nx, int ny, int nz)
{
    xyz2zxy(buf, a, nx, ny, nz);
    dim3 grid((ny - 2 + BLOCK - 1) / BLOCK, (nx - 2 + BLOCK - 1) / BLOCK);
    sweep_z_transposed_kernel<<<grid, dim3(BLOCK, BLOCK)>>>(buf, row_eps, nz, nx, ny);
    zxy2xyz(a, buf, nx, ny, nz);
}

int main(int argc, char *argv[])
{
    const double maxeps = 0.01;
    const int itmax = 10;
    double eps = 0.0;
    int it;

    int nx = 256, ny = 256, nz = 256;
    switch (argc)
    {
    case 2:
        nx = ny = nz = std::stoi(argv[1]);
        break;
    case 4:
        nx = std::stoi(argv[1]);
        ny = std::stoi(argv[2]);
        nz = std::stoi(argv[3]);
        break;
    default:
        break;
    }

    auto start = std::chrono::steady_clock::now();

    auto a = thrust::device_vector<double>(nx * ny * nz);
    auto b = thrust::device_vector<double>(nx * ny * nz);
    auto row_eps = thrust::device_vector<double>((nx - 2) * (ny - 2));

    // init
    {
        double *ptr = thrust::raw_pointer_cast(a.data());
        dim3 block(BLOCK, BLOCK);
        dim3 grid((nz + BLOCK - 1) / BLOCK, (ny + BLOCK - 1) / BLOCK, nx);
        init_kernel<<<grid, block>>>(ptr, nx, ny, nz);
    }

    double *cur = thrust::raw_pointer_cast(a.data());
    double *buf = thrust::raw_pointer_cast(b.data());
    double *eps_buf = thrust::raw_pointer_cast(row_eps.data());

    for (it = 1; it <= itmax; it++)
    {
        sweep_x(cur, nx, ny, nz);
        sweep_y(cur, nx, ny, nz);
        sweep_z(cur, buf, eps_buf, nx, ny, nz);

        eps = thrust::reduce(row_eps.begin(), row_eps.end(), 0.0, thrust::maximum<double>());

        std::cout << " IT = " << std::setw(4) << it
                  << "   EPS = " << std::scientific << std::setprecision(7) << eps << "\n";
        if (eps < maxeps)
            break;
    }

    cudaDeviceSynchronize();
    auto end = std::chrono::steady_clock::now();
    double elapsed = std::chrono::duration<double>(end - start).count();

    std::cout << std::resetiosflags(std::ios::floatfield)
              << " ADI Benchmark Completed.\n"
              << " Size            = " << nx << " x " << ny << " x " << nz << "\n"
              << " Iterations      =       " << itmax << "\n"
              << " Time in seconds =       " << std::fixed << std::setprecision(2) << elapsed << "\n"
              << " Operation type  =   double precision\n"
              << " END OF ADI Benchmark\n";

#ifdef SAVE_OUTPUT
    {
        std::vector<double> host(nx * ny * nz);
        cudaMemcpy(host.data(), cur, (size_t)nx * ny * nz * sizeof(double), cudaMemcpyDeviceToHost);
        std::ofstream out("adi3d_gpu_out", std::ios::binary);
        out.write(reinterpret_cast<const char *>(host.data()),
                  static_cast<std::streamsize>(nx * ny * nz * sizeof(double)));
    }
#endif

    return 0;
}
