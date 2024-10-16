

int main() {

#define VAR float
    
    VAR P = 10;
    VAR I = 1;
    VAR D = 20;
    VAR x[] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}; 
    VAR y[] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0}; //to avoid using heap

    for (int i = 0; i < 10; i++) {
        VAR sum_x = x[0];
        for (int j = 1; j <= i; j++)
            sum_x += x[j];
        
        VAR diff_x;
        if (i != 0)
            diff_x = x[i] - x[i-1];
        else
            diff_x = 0;

        y[i] = (P * x[i]) + (I * sum_x) + (D * diff_x);
    }

    return 0;
}
