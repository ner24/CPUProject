#include <vector>
#include <complex>
#include <cmath>

using namespace std;

typedef complex<double> Complex;
typedef vector<Complex> CArray;

// Define M_PI if not defined
#ifndef M_PI
const double M_PI = 3.14159265358979323846;
#endif

// Custom polar function if not using the standard library
Complex myPolar(double r, double theta) {
    return Complex(r * cos(theta), r * sin(theta));
}

// Function to compute FFT
void fft(CArray &x) {
    int N = x.size();
    if (N <= 1) return;

    // Divide
    CArray even(N / 2);
    CArray odd(N / 2);
    for (int k = 0; k < N / 2; ++k) {
        even[k] = x[k * 2];
        odd[k] = x[k * 2 + 1];
    }

    // Conquer
    fft(even);
    fft(odd);

    // Combine
    for (int k = 0; k < N / 2; ++k) {
        Complex t = myPolar(1.0, -2 * M_PI * k / N) * odd[k];
        x[k] = even[k] + t;
        x[k + N / 2] = even[k] - t;
    }
}

// Example function to demonstrate usage (no console output)
void performFFT() {
    const int N = 8; // Must be a power of 2
    CArray data(N);

    // Initialize data with sample values
    for (int i = 0; i < N; ++i) {
        data[i] = Complex(i, 0); // Example: 0, 1, 2, ..., N-1
    }

    // Perform FFT
    fft(data);

    // The FFT result can be used here as needed
}

int main() {
    performFFT();
    return 0;
}
