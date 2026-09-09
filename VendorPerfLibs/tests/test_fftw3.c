#include <fftw3.h>
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int N = 8;
    fftw_complex *in, *out;
    fftw_plan p;

    /* Allocate memory */
    in = (fftw_complex*) fftw_malloc(sizeof(fftw_complex) * N);
    out = (fftw_complex*) fftw_malloc(sizeof(fftw_complex) * N);

    /* Initialize input with some dummy data */
    for (int i = 0; i < N; i++) {
        in[i][0] = i;      /* Real part */
        in[i][1] = 0.0;    /* Imaginary part */
    }

    /* Create plan */
    p = fftw_plan_dft_1d(N, in, out, FFTW_FORWARD, FFTW_ESTIMATE);

    /* Execute plan */
    fftw_execute(p);

    /* Cleanup */
    fftw_destroy_plan(p);
    fftw_free(in);
    fftw_free(out);

    printf("FFTW3 test completed successfully.\n");
    return 0;
}
