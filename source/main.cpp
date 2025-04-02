#include <raylib.h>
#include <symengine/parser.h>
#include <symengine/symbol.h>
#include <symengine/basic.h>
#include <symengine/dict.h>
#include <symengine/symengine_rcp.h>
#include <symengine/printers.h>

#include <iostream>

using namespace SymEngine;

// Function to compute derivative from a string formula
RCP<const Basic> compute_derivative(const std::string& expr, const RCP<const Symbol>& x) {
    // Parse the input string into a symbolic expression
    RCP<const Basic> f = parse(expr);

    // Compute the derivative w.r.t. 'x'
    return f->diff(x);
}

int
main(void)
{
    InitWindow(900, 900, "TEST");
    SetTargetFPS(60);

    while (! WindowShouldClose())
    {
        BeginDrawing();

        ClearBackground(BLUE);
        DrawRectangle(20, 20, 60, 60, RED);

        std::string fx = "cos(x) + sin(2x)";
        RCP<const Basic> df_dx = compute_derivative(fx, symbol("x"));
        const char *df_dx_str = str(*df_dx).c_str();

        DrawText(df_dx_str, 100, 100, 30, WHITE);

        EndDrawing();
    }

    CloseWindow();

    return 0;
}
